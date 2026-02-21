/**
 * Story Inserter
 * Takes generated story JSON files and inserts them into Firestore
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const { v4: uuidv4 } = require('uuid');

// ==================== CONFIGURATION ====================
const CONFIG = {
  PROJECT_ID: 'arabicstories-82611',
  STORAGE_BUCKET: 'arabicstories-82611.firebasestorage.app',
  STORIES_COLLECTION: 'stories',
  WORDS_COLLECTION: 'quran_words',
  INPUT_DIR: './story-prompts/generated',
  METADATA_FILE: './story-prompts/story-metadata.json',
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

// ==================== STORY BUILDER ====================

/**
 * Create the full story document for Firestore
 */
function createStoryDocument(storyData, words, level, storyIndex) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  const storyId = uuidv4();

  // Build mixed segments from generated data
  const mixedSegments = storyData.segments.map((segment, index) => {
    // Find word IDs for linked words
    const linkedWordIds = [];
    
    // Check for words that appear in this segment
    for (const word of words) {
      if (segment.text.includes(word.arabicText)) {
        linkedWordIds.push(word.id);
      }
    }

    return {
      id: uuidv4(),
      index: index,
      text: segment.text,
      linkedWordIds: linkedWordIds,
      imageURL: null,
      culturalNote: null,
    };
  });

  // Get unique word IDs for learnedWordIds
  const learnedWordIds = words.map(w => w.id);

  // Extract tags from words
  const allTags = new Set();
  words.forEach(w => {
    if (w.tags) {
      w.tags.forEach(tag => allTags.add(tag));
    }
  });

  // Generate description
  const storyDescription = `A ${mixedSegments.length}-segment narrative featuring ${words.length} essential Quranic Arabic words. ${storyData.theme || 'A story of discovery and meaning.'}`;
  
  const storyDescriptionArabic = `سرد من ${mixedSegments.length} أجزاء يضم ${words.length} كلمات عربية قرآنية أساسية.`;

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
    completedWords: {},
    
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

// ==================== FILE LOADING ====================

/**
 * Load metadata file
 */
function loadMetadata() {
  if (!fs.existsSync(CONFIG.METADATA_FILE)) {
    throw new Error(`Metadata file not found: ${CONFIG.METADATA_FILE}. Run story-prompt-generator.js first.`);
  }
  return JSON.parse(fs.readFileSync(CONFIG.METADATA_FILE, 'utf8'));
}

/**
 * Load generated story from JSON file or string
 */
function loadGeneratedStory(storyId) {
  // Try multiple possible file names
  const possiblePaths = [
    path.join(CONFIG.INPUT_DIR, `${storyId}.json`),
    path.join(CONFIG.INPUT_DIR, `story-${storyId}.json`),
    path.join(CONFIG.INPUT_DIR, `level${storyId.split('-')[0]?.replace('level', '')}-story${storyId.split('-')[1]}.json`),
  ];

  for (const filePath of possiblePaths) {
    if (fs.existsSync(filePath)) {
      const content = fs.readFileSync(filePath, 'utf8');
      try {
        return JSON.parse(content);
      } catch (e) {
        // Try extracting JSON from markdown
        const jsonMatch = content.match(/```json\n([\s\S]*?)\n```/) || 
                          content.match(/```\n([\s\S]*?)\n```/) ||
                          content.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          return JSON.parse(jsonMatch[1] || jsonMatch[0]);
        }
      }
    }
  }

  return null;
}

/**
 * Parse story data from pasted content
 */
function parseStoryFromText(text) {
  // Try to extract JSON
  const jsonMatch = text.match(/```json\n([\s\S]*?)\n```/) || 
                    text.match(/```\n([\s\S]*?)\n```/) ||
                    text.match(/(\{[\s\S]*\})/);
  
  if (jsonMatch) {
    try {
      return JSON.parse(jsonMatch[1] || jsonMatch[0]);
    } catch (e) {
      console.error('Failed to parse JSON:', e.message);
    }
  }
  return null;
}

// ==================== INTERACTIVE MODE ====================

async function interactiveMode(db, metadata) {
  const readline = require('readline');
  
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  const ask = (question) => new Promise(resolve => rl.question(question, resolve));

  console.log('\n========================================');
  console.log('Interactive Story Insertion Mode');
  console.log('========================================\n');
  console.log('Paste the generated story JSON when prompted.\n');

  const results = [];

  for (const storyMeta of metadata) {
    console.log(`\n--- Story ${storyMeta.storyNumber}/45 (Level ${storyMeta.level}) ---`);
    console.log(`Words: ${storyMeta.words.map(w => w.arabicText).join(', ')}`);
    
    const answer = await ask('\nPaste story JSON (or press Enter to skip, "exit" to quit): ');
    
    if (answer.toLowerCase() === 'exit') {
      break;
    }
    
    if (!answer.trim()) {
      console.log('  Skipped.');
      continue;
    }

    try {
      const storyData = parseStoryFromText(answer);
      
      if (!storyData) {
        console.log('  ✗ Failed to parse JSON, skipping.');
        continue;
      }

      const storyDoc = createStoryDocument(
        storyData, 
        storyMeta.words, 
        storyMeta.level, 
        storyMeta.storyIndex
      );

      await db.collection(CONFIG.STORIES_COLLECTION).doc(storyDoc.id).set(storyDoc);
      console.log(`  ✓ Saved: ${storyDoc.title} (ID: ${storyDoc.id})`);
      results.push({ success: true, title: storyDoc.title });

    } catch (error) {
      console.error(`  ✗ Error: ${error.message}`);
      results.push({ success: false, error: error.message });
    }
  }

  rl.close();
  return results;
}

// ==================== BATCH MODE ====================

async function batchMode(db, metadata) {
  console.log('\n========================================');
  console.log('Batch Story Insertion Mode');
  console.log('========================================\n');
  console.log(`Looking for generated stories in: ${CONFIG.INPUT_DIR}\n`);

  if (!fs.existsSync(CONFIG.INPUT_DIR)) {
    console.error(`Input directory not found: ${CONFIG.INPUT_DIR}`);
    console.log('Please create this directory and add your generated story JSON files.');
    return [];
  }

  const files = fs.readdirSync(CONFIG.INPUT_DIR).filter(f => f.endsWith('.json'));
  console.log(`Found ${files.length} JSON files\n`);

  const results = [];

  for (const storyMeta of metadata) {
    console.log(`[${storyMeta.storyNumber}/45] Processing Level ${storyMeta.level}, Story ${storyMeta.storyIndex + 1}...`);

    try {
      const storyData = loadGeneratedStory(storyMeta.storyId);
      
      if (!storyData) {
        console.log(`  ⚠ Story file not found, skipping.`);
        continue;
      }

      const storyDoc = createStoryDocument(
        storyData, 
        storyMeta.words, 
        storyMeta.level, 
        storyMeta.storyIndex
      );

      await db.collection(CONFIG.STORIES_COLLECTION).doc(storyDoc.id).set(storyDoc);
      console.log(`  ✓ Saved: ${storyDoc.title}`);
      results.push({ success: true, title: storyDoc.title });

    } catch (error) {
      console.error(`  ✗ Error: ${error.message}`);
      results.push({ success: false, error: error.message });
    }
  }

  return results;
}

// ==================== MAIN ====================

async function insertStories() {
  console.log('========================================');
  console.log('Story Inserter');
  console.log('========================================\n');

  // Load metadata
  let metadata;
  try {
    metadata = loadMetadata();
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }

  console.log(`Loaded metadata for ${metadata.length} stories`);
  console.log(`  Level 1: ${metadata.filter(s => s.level === 1).length} stories`);
  console.log(`  Level 2: ${metadata.filter(s => s.level === 2).length} stories`);
  console.log(`  Level 3: ${metadata.filter(s => s.level === 3).length} stories\n`);

  // Initialize Firebase
  console.log('Initializing Firebase...');
  const db = initializeFirebase();
  console.log('Firebase initialized\n');

  // Check command line args
  const mode = process.argv[2] || 'interactive';
  
  let results;
  if (mode === 'batch') {
    results = await batchMode(db, metadata);
  } else {
    results = await interactiveMode(db, metadata);
  }

  // Summary
  const successCount = results.filter(r => r.success).length;
  const failCount = results.filter(r => !r.success).length;

  console.log('\n========================================');
  console.log('Insertion Complete');
  console.log('========================================');
  console.log(`Success: ${successCount} stories`);
  console.log(`Failed: ${failCount} stories`);
  console.log('========================================');

  process.exit(0);
}

process.on('unhandledRejection', (error) => {
  console.error('Unhandled error:', error);
  process.exit(1);
});

insertStories().catch(console.error);
