/**
 * Story Prompt Generator for Kimi
 * Generates prompts that you can copy-paste to Kimi to create stories
 * 
 * Configuration: 15 stories per level, 66 words per level
 * Each story teaches ~4-5 words (shuffled/randomized)
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// ==================== CONFIGURATION ====================
const CONFIG = {
  PROJECT_ID: 'arabicstories-82611',
  STORAGE_BUCKET: 'arabicstories-82611.firebasestorage.app',
  WORDS_COLLECTION: 'quran_words',
  WORDS_PER_LEVEL: 66,
  STORIES_PER_LEVEL: 15,
  TOTAL_LEVELS: 3,
  WORDS_PER_STORY: 4, // ~4-5 words per story (66/15 ≈ 4.4)
  SEGMENTS_PER_STORY: 10,
  OUTPUT_DIR: './story-prompts',
};

// ==================== FIREBASE INITIALIZATION ====================

function initializeFirebase() {
  const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');
  
  if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      storageBucket: CONFIG.STORAGE_BUCKET,
    });
  } else {
    admin.initializeApp({
      storageBucket: CONFIG.STORAGE_BUCKET,
    });
  }
  
  return admin.firestore();
}

// ==================== UTILITY FUNCTIONS ====================

/**
 * Shuffle array using Fisher-Yates algorithm
 */
function shuffleArray(array) {
  const shuffled = [...array];
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  return shuffled;
}

/**
 * Chunk array into groups of specified size
 */
function chunkArray(array, chunkSize) {
  const chunks = [];
  for (let i = 0; i < array.length; i += chunkSize) {
    chunks.push(array.slice(i, i + chunkSize));
  }
  return chunks;
}

/**
 * Distribute words evenly across stories with some randomness
 */
function distributeWordsForLevel(words, numStories) {
  // Shuffle words first
  const shuffled = shuffleArray(words);
  
  // Calculate base words per story and remainder
  const baseCount = Math.floor(words.length / numStories);
  const remainder = words.length % numStories;
  
  const storyWords = [];
  let wordIndex = 0;
  
  for (let i = 0; i < numStories; i++) {
    // First 'remainder' stories get one extra word
    const count = i < remainder ? baseCount + 1 : baseCount;
    storyWords.push(shuffled.slice(wordIndex, wordIndex + count));
    wordIndex += count;
  }
  
  // Shuffle the story order so words appear in random order across stories
  return shuffleArray(storyWords);
}

// ==================== PROMPT GENERATION ====================

/**
 * Generate a story prompt for Kimi
 */
function generatePrompt(words, level, storyIndex, storyId) {
  const wordList = words.map(w => {
    const pos = w.morphology?.posDescription || w.morphology?.partOfSpeech || 'word';
    return `- "${w.arabicText}" (${w.englishMeaning}) - ${pos} - occurs ${w.occurrenceCount || '?'} times in Quran`;
  }).join('\n');

  const wordIds = words.map(w => `"${w.id}"`).join(', ');

  return `Generate a short Arabic learning story using these Quran vocabulary words.

STORY ID: ${storyId}
LEVEL: ${level}
STORY NUMBER: ${storyIndex + 1}

WORDS TO FEATURE (${words.length} words):
${wordList}

STORY REQUIREMENTS:
1. Create a narrative with exactly ${CONFIG.SEGMENTS_PER_STORY} short segments
2. Each segment should be 1-3 sentences
3. The story should have a coherent theme (journey, discovery, friendship, wisdom, etc.)
4. Target audience: Beginner-intermediate Arabic learners
5. Level ${level} difficulty (Level 1 = simplest words, Level 3 = more complex)

MIXED FORMAT - Embed Arabic words in English sentences with meaning in parentheses:
- Example: "He walked فِى (in) the garden."
- Example: "The كِتَٰبٌ (book) was old."
- Example: "She قَالَتْ (said) the truth."

OUTPUT FORMAT - Return a JSON object exactly like this:

{
  "title": "Story Title in English (creative, thematic)",
  "titleArabic": "عنوان القصة بالعربية",
  "theme": "Brief theme description",
  "segments": [
    {
      "text": "First segment with mixed Arabic/English using the target words...",
      "featuredWords": ["${words[0]?.arabicText || 'word1'}", "${words[1]?.arabicText || 'word2'}"]
    },
    ... (exactly ${CONFIG.SEGMENTS_PER_STORY} segments)
  ]
}

IMPORTANT:
- Feature ALL ${words.length} words naturally across the ${CONFIG.SEGMENTS_PER_STORY} segments
- Some segments can have multiple words, some can have one
- Return ONLY valid JSON, no markdown, no explanation
- Word IDs for linking: [${wordIds}]`;
}

/**
 * Generate a prompt file for batch processing
 */
function generateBatchPrompt(storiesData) {
  let output = `STORY GENERATION BATCH - ${storiesData.length} STORIES\n`;
  output += `Generated: ${new Date().toISOString()}\n`;
  output += `========================================\n\n`;

  for (const story of storiesData) {
    output += `\n--- STORY ${story.storyNumber} (Level ${story.level}) ---\n`;
    output += `Story ID: ${story.storyId}\n`;
    output += `Words: ${story.words.map(w => w.arabicText).join(', ')}\n`;
    output += `\nPROMPT:\n`;
    output += generatePrompt(story.words, story.level, story.storyIndex, story.storyId);
    output += `\n\n========================================\n`;
  }

  return output;
}

/**
 * Generate a summary file
 */
function generateSummary(allStories) {
  let output = `STORY GENERATION SUMMARY\n`;
  output += `========================\n\n`;
  output += `Total Stories: ${allStories.length}\n`;
  output += `Stories per Level: ${CONFIG.STORIES_PER_LEVEL}\n`;
  output += `Words per Level: ${CONFIG.WORDS_PER_LEVEL}\n\n`;

  for (let level = 1; level <= CONFIG.TOTAL_LEVELS; level++) {
    const levelStories = allStories.filter(s => s.level === level);
    output += `\n--- LEVEL ${level} ---\n`;
    
    for (const story of levelStories) {
      output += `Story ${story.storyIndex + 1}: ${story.words.length} words - ${story.words.map(w => w.arabicText).join(', ')}\n`;
    }
  }

  return output;
}

// ==================== MAIN ====================

async function generatePrompts() {
  console.log('========================================');
  console.log('Story Prompt Generator for Kimi');
  console.log('========================================\n');
  console.log(`Configuration:`);
  console.log(`  - ${CONFIG.TOTAL_LEVELS} levels`);
  console.log(`  - ${CONFIG.STORIES_PER_LEVEL} stories per level`);
  console.log(`  - ${CONFIG.WORDS_PER_LEVEL} words per level`);
  console.log(`  - ~${(CONFIG.WORDS_PER_LEVEL / CONFIG.STORIES_PER_LEVEL).toFixed(1)} words per story\n`);

  // Create output directory
  if (!fs.existsSync(CONFIG.OUTPUT_DIR)) {
    fs.mkdirSync(CONFIG.OUTPUT_DIR, { recursive: true });
  }

  console.log('Initializing Firebase...');
  const db = initializeFirebase();
  console.log('Firebase initialized\n');

  // Fetch all words
  console.log('Fetching words from Firestore...');
  const snapshot = await db.collection(CONFIG.WORDS_COLLECTION)
    .orderBy('rank', 'asc')
    .get();

  const allWords = [];
  snapshot.forEach(doc => {
    allWords.push({
      id: doc.id,
      ...doc.data(),
    });
  });

  console.log(`Found ${allWords.length} words total\n`);

  // Group into levels
  const levels = {};
  for (let level = 1; level <= CONFIG.TOTAL_LEVELS; level++) {
    const startIdx = (level - 1) * CONFIG.WORDS_PER_LEVEL;
    const endIdx = Math.min(startIdx + CONFIG.WORDS_PER_LEVEL, allWords.length);
    levels[level] = allWords.slice(startIdx, endIdx);
  }

  // Generate prompts for each level
  const allStories = [];

  for (let level = 1; level <= CONFIG.TOTAL_LEVELS; level++) {
    console.log(`\n========================================`);
    console.log(`Processing LEVEL ${level}`);
    console.log(`========================================`);

    const levelWords = levels[level];
    if (levelWords.length === 0) {
      console.log(`  No words for level ${level}, skipping`);
      continue;
    }

    // Distribute words across stories (shuffled)
    const storyWordGroups = distributeWordsForLevel(levelWords, CONFIG.STORIES_PER_LEVEL);

    const levelStories = [];
    for (let i = 0; i < CONFIG.STORIES_PER_LEVEL; i++) {
      const words = storyWordGroups[i];
      const storyId = `level${level}-story${i + 1}-${Date.now()}`;
      
      levelStories.push({
        storyId,
        level,
        storyIndex: i,
        storyNumber: (level - 1) * CONFIG.STORIES_PER_LEVEL + i + 1,
        words,
      });

      console.log(`  Story ${i + 1}: ${words.length} words [${words.map(w => w.arabicText).join(', ')}]`);
    }

    // Save individual prompts for this level
    const batchPrompt = generateBatchPrompt(levelStories);
    const batchFile = path.join(CONFIG.OUTPUT_DIR, `level-${level}-prompts.txt`);
    fs.writeFileSync(batchFile, batchPrompt);
    console.log(`  ✓ Saved prompts to: ${batchFile}`);

    allStories.push(...levelStories);
  }

  // Save summary
  const summaryContent = generateSummary(allStories);
  const summaryFile = path.join(CONFIG.OUTPUT_DIR, 'summary.txt');
  fs.writeFileSync(summaryFile, summaryContent);
  console.log(`\n✓ Saved summary to: ${summaryFile}`);

  // Save story metadata for later insertion
  const metadataFile = path.join(CONFIG.OUTPUT_DIR, 'story-metadata.json');
  fs.writeFileSync(metadataFile, JSON.stringify(allStories, null, 2));
  console.log(`✓ Saved metadata to: ${metadataFile}`);

  // Create a single combined prompt file for easy copy-paste
  const combinedPrompts = allStories.map(story => {
    return `\n========================================\n` +
           `STORY ${story.storyNumber}/45 (Level ${story.level}, Story ${story.storyIndex + 1})\n` +
           `========================================\n\n` +
           generatePrompt(story.words, story.level, story.storyIndex, story.storyId) +
           `\n\n`;
  }).join('\n');

  const combinedFile = path.join(CONFIG.OUTPUT_DIR, 'all-prompts.txt');
  fs.writeFileSync(combinedFile, combinedPrompts);
  console.log(`✓ Saved all prompts to: ${combinedFile}`);

  console.log('\n========================================');
  console.log('Prompt Generation Complete!');
  console.log('========================================');
  console.log(`\nNext steps:`);
  console.log(`1. Open ${CONFIG.OUTPUT_DIR}/all-prompts.txt`);
  console.log(`2. Copy each prompt and paste to Kimi (me!) to generate stories`);
  console.log(`3. Save the generated JSON responses to ${CONFIG.OUTPUT_DIR}/generated/`);
  console.log(`4. Run: node story-insert.js to insert into Firestore`);
  console.log(`\nAlternative: Send me the all-prompts.txt file content and I'll generate all stories at once!`);
  console.log('========================================');

  process.exit(0);
}

process.on('unhandledRejection', (error) => {
  console.error('Unhandled error:', error);
  process.exit(1);
});

generatePrompts().catch(console.error);
