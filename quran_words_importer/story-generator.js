/**
 * Quran Words Story Generator
 * Generates 33 stories (11 per level) using AI and saves to Firestore
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const { v4: uuidv4 } = require('uuid');
const axios = require('axios');

// ==================== CONFIGURATION ====================
const CONFIG = {
  PROJECT_ID: 'arabicstories-82611',
  STORAGE_BUCKET: 'arabicstories-82611.firebasestorage.app',
  DATABASE_LOCATION: 'nam5',
  WORDS_COLLECTION: 'quran_words',
  STORIES_COLLECTION: 'stories',
  WORDS_PER_LEVEL: 66,
  STORIES_PER_LEVEL: 11,
  TOTAL_LEVELS: 3,
  // AI Provider: 'openai', 'anthropic', or 'custom'
  AI_PROVIDER: process.env.AI_PROVIDER || 'anthropic',
  OPENAI_API_KEY: process.env.OPENAI_API_KEY,
  ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY,
  // Story generation settings
  SEGMENTS_PER_STORY: 10,
  WORDS_PER_STORY: 6, // Number of unique words to feature in each story
};

// ==================== FIREBASE INITIALIZATION ====================

function initializeFirebase() {
  const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');
  
  if (fs.existsSync(serviceAccountPath)) {
    console.log('Using service account authentication');
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      storageBucket: CONFIG.STORAGE_BUCKET,
    });
  } else {
    console.log('Using application default credentials');
    admin.initializeApp({
      storageBucket: CONFIG.STORAGE_BUCKET,
    });
  }
  
  return admin.firestore();
}

// ==================== AI STORY GENERATION ====================

/**
 * Generate story using Anthropic Claude API
 */
async function generateWithClaude(prompt) {
  if (!CONFIG.ANTHROPIC_API_KEY) {
    throw new Error('ANTHROPIC_API_KEY not set in environment');
  }

  try {
    const response = await axios.post(
      'https://api.anthropic.com/v1/messages',
      {
        model: 'claude-3-sonnet-20240229',
        max_tokens: 4000,
        messages: [{ role: 'user', content: prompt }],
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': CONFIG.ANTHROPIC_API_KEY,
          'anthropic-version': '2023-06-01',
        },
      }
    );

    return response.data.content[0].text;
  } catch (error) {
    console.error('Claude API error:', error.response?.data || error.message);
    throw error;
  }
}

/**
 * Generate story using OpenAI GPT API
 */
async function generateWithOpenAI(prompt) {
  if (!CONFIG.OPENAI_API_KEY) {
    throw new Error('OPENAI_API_KEY not set in environment');
  }

  try {
    const response = await axios.post(
      'https://api.openai.com/v1/chat/completions',
      {
        model: 'gpt-4',
        messages: [{ role: 'user', content: prompt }],
        temperature: 0.8,
        max_tokens: 4000,
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${CONFIG.OPENAI_API_KEY}`,
        },
      }
    );

    return response.data.choices[0].message.content;
  } catch (error) {
    console.error('OpenAI API error:', error.response?.data || error.message);
    throw error;
  }
}

/**
 * Generate story based on selected words using configured AI provider
 */
async function generateStoryWithAI(words, level, storyIndex) {
  const wordList = words.map(w => 
    `- "${w.arabicText}" (${w.englishMeaning}) - ${w.morphology?.posDescription || 'word'} - occurs ${w.occurrenceCount} times in Quran`
  ).join('\n');

  const prompt = `You are creating a short, meaningful story for Arabic language learners using specific Quran vocabulary.

STORY REQUIREMENTS:
- Create a narrative with exactly ${CONFIG.SEGMENTS_PER_STORY} short segments/paragraphs
- Each segment should be 1-3 sentences
- The story should have a coherent theme (friendship, journey, discovery, wisdom, etc.)
- Target audience: Beginner-intermediate Arabic learners

VOCABULARY TO USE (feature these words naturally in the story):
${wordList}

MIXED FORMAT INSTRUCTIONS:
Embed the Arabic words directly into English sentences with the English meaning in parentheses.
Examples:
- "He walked فِى (in) the garden."
- "The كِتَٰبٌ (book) was old."
- "She قَالَتْ (said) the truth."

OUTPUT FORMAT - Return ONLY a JSON object like this:
{
  "title": "Story Title in English",
  "titleArabic": "عنوان القصة بالعربية",
  "theme": "Brief theme description",
  "segments": [
    {
      "text": "First segment with mixed Arabic/English...",
      "featuredWords": ["word1", "word2"]
    },
    ... (10 segments total)
  ]
}

IMPORTANT:
- Use the Arabic words naturally within English sentences
- Vary the grammatical forms when possible (the word database includes morphology info)
- Create a cohesive narrative, not random sentences
- Each segment should feature 1-3 of the target words
- Return valid JSON only, no markdown formatting`;

  console.log(`  Calling AI (${CONFIG.AI_PROVIDER}) for story ${storyIndex + 1}...`);
  
  let response;
  if (CONFIG.AI_PROVIDER === 'anthropic') {
    response = await generateWithClaude(prompt);
  } else if (CONFIG.AI_PROVIDER === 'openai') {
    response = await generateWithOpenAI(prompt);
  } else {
    throw new Error(`Unknown AI provider: ${CONFIG.AI_PROVIDER}`);
  }

  // Extract JSON from response
  const jsonMatch = response.match(/\{[\s\S]*\}/);
  if (!jsonMatch) {
    throw new Error('AI response did not contain valid JSON');
  }

  return JSON.parse(jsonMatch[0]);
}

// ==================== STORY FORMATTING ====================

/**
 * Create mixed segments from AI-generated story
 */
function createMixedSegments(storyData, words) {
  const wordMap = new Map(words.map(w => [w.arabicText, w]));
  const mixedSegments = [];

  for (let i = 0; i < storyData.segments.length; i++) {
    const segment = storyData.segments[i];
    const linkedWordIds = [];

    // Find which words from our vocabulary are featured in this segment
    for (const word of words) {
      if (segment.text.includes(word.arabicText)) {
        linkedWordIds.push(word.id);
      }
    }

    mixedSegments.push({
      id: uuidv4(),
      index: i,
      text: segment.text,
      linkedWordIds: linkedWordIds,
      imageURL: null,
      culturalNote: null,
    });
  }

  return mixedSegments;
}

/**
 * Create the full story document for Firestore
 */
function createStoryDocument(storyData, mixedSegments, words, level, storyIndex) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  const storyId = uuidv4();

  // Get unique word IDs for learnedWordIds
  const learnedWordIds = words.map(w => w.id);

  // Create completedWords map (initially empty)
  const completedWords = {};

  // Extract tags from words
  const allTags = new Set();
  words.forEach(w => {
    if (w.tags) {
      w.tags.forEach(tag => allTags.add(tag));
    }
  });

  // Generate description
  const storyDescription = `A ${CONFIG.SEGMENTS_PER_STORY}-segment narrative featuring ${words.length} essential Quranic Arabic words. ${storyData.theme || 'A story of discovery and meaning.'}`;
  
  const storyDescriptionArabic = `سرد من ${CONFIG.SEGMENTS_PER_STORY} أجزاء يضم ${words.length} كلمات عربية قرآنية أساسية.`;

  return {
    id: storyId,
    title: storyData.title,
    titleArabic: storyData.titleArabic,
    storyDescription,
    storyDescriptionArabic,
    author: 'Quran Vocabulary Series',
    category: 'general',
    format: 'mixed',
    difficultyLevel: level,
    
    // Arrays
    mixedSegments,
    learnedWordIds,
    tags: Array.from(allTags),
    grammarNotes: [],
    segments: [], // Empty for mixed format
    
    // Maps
    completedWords,
    
    // Progress tracking
    currentSegmentIndex: 0,
    readingProgress: 0,
    completionCount: 0,
    totalReadingTime: 0,
    viewCount: 0,
    
    // Ratings
    averageRating: null,
    
    // URLs
    coverImageURL: null,
    audioNarrationURL: null,
    sourceURL: null,
    
    // User data
    isBookmarked: false,
    isDownloaded: false,
    isUserCreated: false,
    downloadDate: null,
    
    // Timestamps
    createdAt: now,
    updatedAt: now,
  };
}

// ==================== WORD SELECTION ====================

/**
 * Fetch all words from Firestore and group by levels
 */
async function fetchAndGroupWords(db) {
  console.log('Fetching words from Firestore...');
  
  const snapshot = await db.collection(CONFIG.WORDS_COLLECTION)
    .orderBy('rank', 'asc')
    .get();

  const allWords = [];
  snapshot.forEach(doc => {
    const data = doc.data();
    allWords.push({
      id: doc.id,
      ...data,
    });
  });

  console.log(`Found ${allWords.length} words`);

  // Group into levels
  const levels = {};
  for (let level = 1; level <= CONFIG.TOTAL_LEVELS; level++) {
    const startIdx = (level - 1) * CONFIG.WORDS_PER_LEVEL;
    const endIdx = startIdx + CONFIG.WORDS_PER_LEVEL;
    levels[level] = allWords.slice(startIdx, endIdx);
    console.log(`Level ${level}: ${levels[level].length} words (ranks ${levels[level][0]?.rank || 'N/A'} - ${levels[level][levels[level].length - 1]?.rank || 'N/A'})`);
  }

  return levels;
}

/**
 * Select words for a story (evenly distributed from level)
 */
function selectWordsForStory(levelWords, storyIndex, totalStories) {
  const wordsPerStory = CONFIG.WORDS_PER_STORY;
  const startIdx = (storyIndex * wordsPerStory) % levelWords.length;
  const selected = [];

  for (let i = 0; i < wordsPerStory; i++) {
    const idx = (startIdx + i) % levelWords.length;
    selected.push(levelWords[idx]);
  }

  return selected;
}

// ==================== MAIN GENERATION ====================

async function generateStories() {
  console.log('========================================');
  console.log('Quran Words Story Generator');
  console.log('========================================\n');

  // Check API keys
  if (CONFIG.AI_PROVIDER === 'anthropic' && !CONFIG.ANTHROPIC_API_KEY) {
    console.error('Error: ANTHROPIC_API_KEY environment variable not set');
    console.log('Set it with: export ANTHROPIC_API_KEY=your_key_here');
    process.exit(1);
  }
  if (CONFIG.AI_PROVIDER === 'openai' && !CONFIG.OPENAI_API_KEY) {
    console.error('Error: OPENAI_API_KEY environment variable not set');
    console.log('Set it with: export OPENAI_API_KEY=your_key_here');
    process.exit(1);
  }

  // Initialize Firebase
  console.log('Initializing Firebase...');
  const db = initializeFirebase();
  console.log('Firebase initialized\n');

  // Fetch and group words
  const levels = await fetchAndGroupWords(db);

  const totalStories = CONFIG.TOTAL_LEVELS * CONFIG.STORIES_PER_LEVEL;
  console.log(`\nWill generate ${totalStories} stories total`);
  console.log(`  ${CONFIG.STORIES_PER_LEVEL} stories per level`);
  console.log(`  ${CONFIG.WORDS_PER_STORY} words featured per story`);
  console.log(`  Using AI provider: ${CONFIG.AI_PROVIDER}\n`);

  let successCount = 0;
  let failCount = 0;

  // Generate stories for each level
  for (let level = 1; level <= CONFIG.TOTAL_LEVELS; level++) {
    console.log(`\n========================================`);
    console.log(`Generating stories for LEVEL ${level}`);
    console.log(`========================================`);

    const levelWords = levels[level];

    for (let i = 0; i < CONFIG.STORIES_PER_LEVEL; i++) {
      const storyNum = (level - 1) * CONFIG.STORIES_PER_LEVEL + i + 1;
      console.log(`\n[${storyNum}/${totalStories}] Generating story ${i + 1} for Level ${level}...`);

      try {
        // Select words for this story
        const selectedWords = selectWordsForStory(levelWords, i, CONFIG.STORIES_PER_LEVEL);
        console.log(`  Selected words: ${selectedWords.map(w => w.arabicText).join(', ')}`);

        // Generate story with AI
        const storyData = await generateStoryWithAI(selectedWords, level, i);
        console.log(`  Title: ${storyData.title}`);
        console.log(`  Theme: ${storyData.theme || 'N/A'}`);

        // Create mixed segments
        const mixedSegments = createMixedSegments(storyData, selectedWords);
        console.log(`  Created ${mixedSegments.length} mixed segments`);

        // Create full document
        const storyDoc = createStoryDocument(storyData, mixedSegments, selectedWords, level, i);

        // Save to Firestore
        await db.collection(CONFIG.STORIES_COLLECTION).doc(storyDoc.id).set(storyDoc);
        console.log(`  ✓ Saved to Firestore (ID: ${storyDoc.id})`);

        successCount++;

        // Rate limiting delay between API calls
        if (i < CONFIG.STORIES_PER_LEVEL - 1 || level < CONFIG.TOTAL_LEVELS) {
          console.log('  Waiting 2 seconds before next story...');
          await new Promise(resolve => setTimeout(resolve, 2000));
        }

      } catch (error) {
        console.error(`  ✗ Failed: ${error.message}`);
        failCount++;
      }
    }
  }

  console.log('\n========================================');
  console.log('Story Generation Complete');
  console.log('========================================');
  console.log(`Success: ${successCount} stories`);
  console.log(`Failed: ${failCount} stories`);
  console.log('========================================');

  process.exit(0);
}

// Handle errors
process.on('unhandledRejection', (error) => {
  console.error('Unhandled error:', error);
  process.exit(1);
});

// Run
generateStories().catch(console.error);
