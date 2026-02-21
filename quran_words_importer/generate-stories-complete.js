/**
 * Complete Story Generator
 * Uses words from Firestore quran_words collection to create 45 stories
 * and inserts them into stories collection
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const { v4: uuidv4 } = require('uuid');

// ==================== CONFIGURATION ====================
const CONFIG = {
  PROJECT_ID: 'arabicstories-82611',
  STORAGE_BUCKET: 'arabicstories-82611.firebasestorage.app',
  WORDS_COLLECTION: 'quran_words',
  STORIES_COLLECTION: 'stories',
  WORDS_PER_LEVEL: 66,
  STORIES_PER_LEVEL: 15,
  TOTAL_LEVELS: 3,
  SEGMENTS_PER_STORY: 10,
};

// ==================== STORY THEMES ====================
const STORY_THEMES = [
  { title: "The Journey", titleArabic: "الرحلة", theme: "A traveler discovers wisdom through his journey" },
  { title: "The Promise", titleArabic: "الوعد", theme: "A promise made and kept across time" },
  { title: "The Garden", titleArabic: "الحديقة", theme: "Life lessons from tending a garden" },
  { title: "The Book", titleArabic: "الكتاب", theme: "Discovery of ancient wisdom" },
  { title: "The Meeting", titleArabic: "اللقاء", theme: "Two strangers become friends" },
  { title: "The Teacher", titleArabic: "المعلم", theme: "Wisdom passed through generations" },
  { title: "The Night", titleArabic: "الليل", theme: "Reflection and discovery in darkness" },
  { title: "The River", titleArabic: "النهر", theme: "Life lessons from flowing water" },
  { title: "The Gift", titleArabic: "الهبة", theme: "Giving without expecting return" },
  { title: "The Path", titleArabic: "الطريق", theme: "Choosing the right way in life" },
  { title: "The Door", titleArabic: "الباب", theme: "Opportunity and courage" },
  { title: "The Tree", titleArabic: "الشجرة", theme: "Growth and patience" },
  { title: "The Letter", titleArabic: "الرسالة", theme: "Words that change lives" },
  { title: "The Market", titleArabic: "السوق", theme: "Daily life and human connections" },
  { title: "The Mountain", titleArabic: "الجبل", theme: "Overcoming challenges" },
];

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

function shuffleArray(array) {
  const shuffled = [...array];
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  return shuffled;
}

// ==================== STORY GENERATION ====================

/**
 * Generate story segments using the words in mixed format
 */
function generateStoryContent(theme, words) {
  const segments = [];
  const wordList = words.map(w => w.arabicText);
  const wordMeanings = {};
  words.forEach(w => {
    wordMeanings[w.arabicText] = w.englishMeaning;
  });

  // Create contextual story segments
  const segmentTemplates = [
    `There كَانَ (was) a moment when ${wordList[0] || 'the word'} (${wordMeanings[wordList[0]] || 'meaning'}) became clear.`,
    `He came مِّنَ (from) a place where ${wordList[1] || 'learning'} (${wordMeanings[wordList[1]] || 'wisdom'}) began.`,
    `She saw ذَٰلِكَ (that) ${wordList[2] || 'truth'} (${wordMeanings[wordList[2]] || 'reality'}) with her heart.`,
    `They قَالُوا۟ (said) words of ${wordList[3] || 'peace'} (${wordMeanings[wordList[3]] || 'harmony'}) to each other.`,
    `In this ${theme.toLowerCase()}, there كَانَ (was) always hope.`,
    `The path led مِّنَ (from) darkness into light.`,
    `He remembered ذَٰلِكَ (that) promise he made long ago.`,
    `She knew إِنَّ (indeed) truth would prevail.`,
    `Together they walked, and مَا (what) they found was precious.`,
    `There كَانَ (was) completion, and they were at peace.`
  ];

  // Customize segments based on available words
  for (let i = 0; i < CONFIG.SEGMENTS_PER_STORY; i++) {
    let text = segmentTemplates[i];
    
    // Replace placeholders with actual words if available
    if (i < words.length) {
      const word = words[i];
      // Already embedded in template
    }
    
    segments.push({
      index: i,
      text: text,
      featuredWords: i < words.length ? [words[i].arabicText] : []
    });
  }

  return segments;
}

/**
 * Create the full story document
 */
function createStoryDocument(themeData, words, level, storyIndex) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  const storyId = uuidv4();

  // Generate segments
  const segments = generateStoryContent(themeData.theme, words);
  
  // Build mixed segments with linked word IDs
  const mixedSegments = segments.map((seg, index) => {
    const linkedWordIds = [];
    
    // Find which words appear in this segment
    for (const word of words) {
      if (seg.text.includes(word.arabicText)) {
        linkedWordIds.push(word.id);
      }
    }

    return {
      id: uuidv4(),
      index: index,
      text: seg.text,
      linkedWordIds: linkedWordIds,
      imageURL: null,
      culturalNote: null,
    };
  });

  const learnedWordIds = words.map(w => w.id);
  
  // Extract unique tags
  const allTags = new Set();
  words.forEach(w => {
    if (w.tags) w.tags.forEach(tag => allTags.add(tag));
  });

  const storyDescription = `A ${CONFIG.SEGMENTS_PER_STORY}-segment narrative: ${themeData.theme}. Features ${words.length} essential Quranic Arabic words.`;
  const storyDescriptionArabic = `سرد من ${CONFIG.SEGMENTS_PER_STORY} أجزاء: ${themeData.theme}.`;

  return {
    id: storyId,
    title: themeData.title,
    titleArabic: themeData.titleArabic,
    storyDescription,
    storyDescriptionArabic,
    author: 'Quran Vocabulary Series',
    category: 'general',
    format: 'mixed',
    difficultyLevel: level,
    
    mixedSegments,
    learnedWordIds,
    tags: Array.from(allTags),
    grammarNotes: [],
    segments: [],
    
    completedWords: {},
    
    currentSegmentIndex: 0,
    readingProgress: 0,
    completionCount: 0,
    totalReadingTime: 0,
    viewCount: 0,
    
    averageRating: null,
    
    coverImageURL: null,
    audioNarrationURL: null,
    sourceURL: null,
    
    isBookmarked: false,
    isDownloaded: false,
    isUserCreated: false,
    downloadDate: null,
    
    createdAt: now,
    updatedAt: now,
  };
}

/**
 * Distribute words across stories with randomization
 */
function distributeWordsForStories(words, numStories) {
  const shuffled = shuffleArray(words);
  const baseCount = Math.floor(words.length / numStories);
  const remainder = words.length % numStories;
  
  const storyWords = [];
  let wordIndex = 0;
  
  for (let i = 0; i < numStories; i++) {
    const count = i < remainder ? baseCount + 1 : baseCount;
    storyWords.push(shuffled.slice(wordIndex, wordIndex + count));
    wordIndex += count;
  }
  
  return shuffleArray(storyWords);
}

// ==================== MAIN ====================

async function generateStories() {
  console.log('========================================');
  console.log('Complete Story Generator');
  console.log('========================================\n');
  console.log(`Configuration:`);
  console.log(`  - ${CONFIG.TOTAL_LEVELS} levels`);
  console.log(`  - ${CONFIG.STORIES_PER_LEVEL} stories per level`);
  console.log(`  - ${CONFIG.WORDS_PER_LEVEL} words per level (ideal)`);
  console.log(`  - ~${(CONFIG.WORDS_PER_LEVEL / CONFIG.STORIES_PER_LEVEL).toFixed(1)} words per story (shuffled)`);
  console.log(`  - Total: ${CONFIG.TOTAL_LEVELS * CONFIG.STORIES_PER_LEVEL} stories\n`);

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

  console.log(`Found ${allWords.length} words in Firestore`);

  if (allWords.length === 0) {
    console.error('No words found! Please import words first: npm start');
    process.exit(1);
  }

  // Group into levels
  const levels = {};
  for (let level = 1; level <= CONFIG.TOTAL_LEVELS; level++) {
    const startIdx = (level - 1) * CONFIG.WORDS_PER_LEVEL;
    const endIdx = Math.min(startIdx + CONFIG.WORDS_PER_LEVEL, allWords.length);
    levels[level] = allWords.slice(startIdx, endIdx);
    console.log(`Level ${level}: ${levels[level].length} words (ranks ${levels[level][0]?.rank || 'N/A'} - ${levels[level][levels[level].length - 1]?.rank || 'N/A'})`);
  }

  const totalStories = CONFIG.TOTAL_LEVELS * CONFIG.STORIES_PER_LEVEL;
  console.log(`\nWill generate ${totalStories} stories\n`);

  let successCount = 0;
  let skipCount = 0;

  for (let level = 1; level <= CONFIG.TOTAL_LEVELS; level++) {
    console.log(`\n========================================`);
    console.log(`Generating stories for LEVEL ${level}`);
    console.log(`========================================`);

    const levelWords = levels[level];
    if (levelWords.length === 0) {
      console.log(`  No words for level ${level}, skipping`);
      skipCount += CONFIG.STORIES_PER_LEVEL;
      continue;
    }

    // Distribute words across stories (shuffled)
    const storyWordGroups = distributeWordsForStories(levelWords, CONFIG.STORIES_PER_LEVEL);

    for (let i = 0; i < CONFIG.STORIES_PER_LEVEL; i++) {
      const storyNum = (level - 1) * CONFIG.STORIES_PER_LEVEL + i + 1;
      const theme = STORY_THEMES[i % STORY_THEMES.length];
      const words = storyWordGroups[i];
      
      console.log(`\n[${storyNum}/${totalStories}] ${theme.title}`);
      console.log(`  Words: ${words.map(w => w.arabicText).join(', ')} (${words.length} words)`);

      try {
        const storyDoc = createStoryDocument(theme, words, level, i);
        
        await db.collection(CONFIG.STORIES_COLLECTION).doc(storyDoc.id).set(storyDoc);
        console.log(`  ✓ Saved to Firestore (ID: ${storyDoc.id})`);

        successCount++;

      } catch (error) {
        console.error(`  ✗ Failed: ${error.message}`);
      }
    }
  }

  console.log('\n========================================');
  console.log('Story Generation Complete');
  console.log('========================================');
  console.log(`Success: ${successCount} stories`);
  console.log(`Skipped: ${skipCount} stories (no words)`);
  console.log('========================================');

  process.exit(0);
}

process.on('unhandledRejection', (error) => {
  console.error('Unhandled error:', error);
  process.exit(1);
});

generateStories().catch(console.error);
