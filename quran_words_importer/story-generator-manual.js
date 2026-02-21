/**
 * Manual Story Generator (No AI Required)
 * Creates stories using pre-written templates with Quran words
 * Use this if you don't have AI API access
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
};

// ==================== STORY TEMPLATES ====================
// Pre-written story frameworks that can be adapted with different words

const STORY_TEMPLATES = [
  {
    title: "The Journey",
    titleArabic: "الرحلة",
    theme: "A traveler discovers wisdom through his journey",
    segmentPatterns: [
      "There كَانَ (was) a {NOUN}. He wanted to {VERB}.",
      "He went مِنَ (from) his home. The {NOUN} followed him.",
      "He saw ذَٰلِكَ (that) {NOUN}. It كَانَ (was) beautiful.",
      "He قَالَ (said) to himself: 'I will {VERB}.'",
      "The {NOUN} كَانَ (was) waiting for him.",
      "He walked مِّنَ (through) the {NOUN}. He felt peace.",
      "He reached ذَٰلِكَ (that) place. There كَانَ (were) many {NOUN}.",
      "He began to {VERB}. He learned مِّنَ (from) the {NOUN}.",
      "The day كَانَ (was) ending. He remembered ذَٰلِكَ (that) moment.",
      "He returned مِنَ (from) the journey. He كَانَ (was) changed."
    ],
  },
  {
    title: "The Promise",
    titleArabic: "الوعد",
    theme: "A promise made and kept across time",
    segmentPatterns: [
      "There كَانَ (was) a boy. He made a promise.",
      "He came مِّنَ (from) a distant land. He carried hope.",
      "He saw ذَٰلِكَ (that) mountain. It كَانَ (was) tall.",
      "He قَالَ (said): 'I will climb it.' He began.",
      "He walked مِّنَ (through) valleys. He never stopped.",
      "He remembered ذَٰلِكَ (that) promise every day.",
      "There كَانَ (were) difficulties. He continued.",
      "He reached the top. He قَالَ (said) a prayer.",
      "The view كَانَ (was) beautiful. He understood.",
      "He descended مِنَ (from) the mountain. He kept his promise."
    ],
  },
  {
    title: "The Garden",
    titleArabic: "الحديقة",
    theme: "Life lessons from tending a garden",
    segmentPatterns: [
      "There كَانَ (was) a garden. It needed care.",
      "The gardener came مِنَ (from) his home. He brought tools.",
      "He saw ذَٰلِكَ (that) flower. It كَانَ (was) wilted.",
      "He قَالَ (said): 'I will help it grow.'",
      "He worked مِّنَ (from) morning to night. He was patient.",
      "The garden كَانَ (was) his teacher.",
      "He learned مِّنَ (from) the soil. He learned مِّنَ (from) the sun.",
      "He remembered ذَٰلِكَ (that) wilted flower. Now it bloomed.",
      "The flowers كَانَ (were) grateful. The garden flourished.",
      "He sat in ذَٰلِكَ (that) garden. He found peace."
    ],
  },
  {
    title: "The Book",
    titleArabic: "الكتاب",
    theme: "Discovery of ancient wisdom",
    segmentPatterns: [
      "There كَانَ (was) a library. It held secrets.",
      "The scholar came مِّنَ (from) afar. He sought knowledge.",
      "He found ذَٰلِكَ (that) book. It كَانَ (was) old.",
      "He opened it carefully. He قَالَ (said) Bismillah.",
      "He read مِّنَ (from) page to page. Words came alive.",
      "The book كَانَ (was) a treasure.",
      "He learned مِّنَ (from) the wisdom. His heart opened.",
      "He copied ذَٰلِكَ (that) knowledge. He shared it.",
      "People came مِنَ (from) everywhere. They wanted to learn.",
      "The book كَانَ (was) complete. The knowledge spread."
    ],
  },
  {
    title: "The Meeting",
    titleArabic: "اللقاء",
    theme: "Two strangers become friends",
    segmentPatterns: [
      "There كَانَ (was) a traveler. He was alone.",
      "He walked مِّنَ (through) the market. He saw many people.",
      "He noticed ذَٰلِكَ (that) person. They كَانَ (were) reading.",
      "He approached. He قَالَ (said): 'Peace be upon you.'",
      "The person smiled. They began to speak مِّنَ (from) their hearts.",
      "The conversation كَانَ (was) easy. Time passed.",
      "They came مِنَ (from) different lands. They found connection.",
      "They shared ذَٰلِكَ (that) moment. It كَانَ (was) special.",
      "The sun كَانَ (was) setting. They made plans.",
      "They parted as friends. They knew ذَٰلِكَ (that) meeting was fate."
    ],
  },
  {
    title: "The Teacher",
    titleArabic: "المعلم",
    theme: "Wisdom passed through generations",
    segmentPatterns: [
      "There كَانَ (was) a teacher. He had knowledge.",
      "Students came مِنَ (from) everywhere. They wanted to learn.",
      "He taught them ذَٰلِكَ (that) lesson. It كَانَ (was) important.",
      "He قَالَ (said): 'Knowledge is light.'",
      "The students listened. They wrote مِّنَ (from) what he taught.",
      "The class كَانَ (was) full of questions.",
      "He answered مِّنَ (from) his experience. He was patient.",
      "He remembered ذَٰلِكَ (that) day he was a student.",
      "The lesson كَانَ (was) complete. The students understood.",
      "They left with wisdom. The teacher smiled."
    ],
  },
  {
    title: "The Night",
    titleArabic: "الليل",
    theme: "Reflection and discovery in darkness",
    segmentPatterns: [
      "There كَانَ (was) a night. It was quiet.",
      "The man came مِنَ (from) his work. He was tired.",
      "He saw ذَٰلِكَ (that) star. It كَانَ (was) bright.",
      "He قَالَ (said): 'How beautiful is the night.'",
      "He sat outside. He thought مِّنَ (from) his heart.",
      "The night كَانَ (was) peaceful. His worries left.",
      "He remembered مِّنَ (from) his childhood. He used to watch stars.",
      "He found ذَٰلِكَ (that) same wonder. It كَانَ (was) still there.",
      "The moon كَانَ (was) full. The world was calm.",
      "He went inside renewed. The night had blessed him."
    ],
  },
  {
    title: "The River",
    titleArabic: "النهر",
    theme: "Life lessons from flowing water",
    segmentPatterns: [
      "There كَانَ (was) a river. It flowed forever.",
      "The water came مِنَ (from) the mountain. It was clear.",
      "A child saw ذَٰلِكَ (that) river. He wondered.",
      "He قَالَ (said): 'Where does it go?'",
      "His grandfather answered. He spoke مِّنَ (from) wisdom.",
      "The river كَانَ (was) patient. It reached the sea.",
      "The child learned مِّنَ (from) the water. He learned to flow.",
      "He touched ذَٰلِكَ (that) water. It كَانَ (was) cool.",
      "The river taught him. Obstacles كَانَ (were) not problems.",
      "He became like the river. He found his way."
    ],
  },
  {
    title: "The Gift",
    titleArabic: "الهبة",
    theme: "Giving without expecting return",
    segmentPatterns: [
      "There كَانَ (was) a merchant. He had much.",
      "A poor man came مِنَ (from) the street. He needed help.",
      "The merchant saw ذَٰلِكَ (that) need. His heart moved.",
      "He قَالَ (said): 'Take this. It is yours.'",
      "He gave مِّنَ (from) what he had. He gave generously.",
      "The poor man كَانَ (was) grateful. His eyes filled.",
      "The merchant learned مِّنَ (from) giving. He felt rich.",
      "He remembered ذَٰلِكَ (that) moment. It كَانَ (was) precious.",
      "His wealth كَانَ (was) not in gold. It was in his heart.",
      "He gave more each day. He found true wealth."
    ],
  },
  {
    title: "The Path",
    titleArabic: "الطريق",
    theme: "Choosing the right way in life",
    segmentPatterns: [
      "There كَانَ (was) a crossroads. Two paths diverged.",
      "The traveler came مِنَ (from) a long journey. He was tired.",
      "He saw ذَٰلِكَ (that) first path. It looked easy.",
      "He قَالَ (said): 'But is it right?' He thought.",
      "He looked at the second. It seemed hard.",
      "The choice كَانَ (was) important. He sat to think.",
      "He remembered مِّنَ (from) his father's words. 'Choose well.'",
      "He took ذَٰلِكَ (that) harder path. It كَانَ (was) right.",
      "The journey كَانَ (was) difficult. But he grew.",
      "He reached his destination. He knew he chose correctly."
    ],
  },
  {
    title: "The Door",
    titleArabic: "الباب",
    theme: "Opportunity and courage",
    segmentPatterns: [
      "There كَانَ (was) a door. It was closed.",
      "A young person came مِنَ (from) outside. They were afraid.",
      "They saw ذَٰلِكَ (that) door. It had markings.",
      "They قَالَ (said): 'What is behind it?' They wondered.",
      "They hesitated. Then they reached مِّنَ (from) their courage.",
      "The door كَانَ (was) unlocked. They just needed to push.",
      "They learned مِّنَ (from) their fear. Fear was a teacher.",
      "They opened ذَٰلِكَ (that) door. Light came through.",
      "The room كَانَ (was) beautiful. It waited for them.",
      "They entered. They were glad they tried."
    ],
  },
  {
    title: "The Tree",
    titleArabic: "الشجرة",
    theme: "Growth and patience",
    segmentPatterns: [
      "There كَانَ (was) a seed. It was small.",
      "It came مِنَ (from) a fruit. It fell to earth.",
      "The rain كَانَ (was) its drink. The sun كَانَ (was) its food.",
      "Days passed. The seed قَالَ (said) nothing.",
      "It grew مِّنَ (from) the soil. Slowly, quietly.",
      "People walked by. They did not see ذَٰلِكَ (that) small sprout.",
      "Years كَانَ (were) passing. The tree grew tall.",
      "It became ذَٰلِكَ (that) shade for travelers.",
      "Birds came مِنَ (from) far. They built nests.",
      "The tree كَانَ (was) patient. Now it gives to all."
    ],
  },
  {
    title: "The Letter",
    titleArabic: "الرسالة",
    theme: "Words that change lives",
    segmentPatterns: [
      "There كَانَ (was) a letter. It traveled far.",
      "It came مِنَ (from) a distant friend. It carried hope.",
      "The recipient saw ذَٰلِكَ (that) envelope. His hands shook.",
      "He opened it carefully. He قَالَ (said) Bismillah.",
      "The words كَانَ (were) powerful. They touched his heart.",
      "He read مِّنَ (from) line to line. Tears fell.",
      "He remembered ذَٰلِكَ (that) friendship. It كَانَ (was) precious.",
      "He took a pen. He wrote back مِنَ (from) his soul.",
      "The reply كَانَ (was) full of love.",
      "Two hearts connected. Words bridged the distance."
    ],
  },
  {
    title: "The Market",
    titleArabic: "السوق",
    theme: "Daily life and human connections",
    segmentPatterns: [
      "There كَانَ (was) a market. It was alive.",
      "People came مِنَ (from) everywhere. They brought goods.",
      "A young merchant saw ذَٰلِكَ (that) old woman. She looked tired.",
      "He قَالَ (said): 'Please, take this bread.'",
      "She smiled. Her eyes كَانَ (were) grateful.",
      "He learned مِّنَ (from) her stories. She learned مِنَ (from) his kindness.",
      "The day كَانَ (was) ending. The market closed.",
      "They met again. ذَٰلِكَ (that) friendship grew.",
      "Years passed. The merchant became known.",
      "People remembered مِنَ (from) his generosity. He remembered مِنَ (from) her wisdom."
    ],
  },
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

// ==================== STORY GENERATION ====================

/**
 * Create a story from template using selected words
 */
function generateStoryFromTemplate(template, words, level, storyIndex) {
  // Group words by POS for template filling
  const nouns = words.filter(w => w.morphology?.partOfSpeech === 'N');
  const verbs = words.filter(w => w.morphology?.partOfSpeech === 'V');
  const particles = words.filter(w => w.morphology?.partOfSpeech === 'P');
  const others = words.filter(w => !['N', 'V', 'P'].includes(w.morphology?.partOfSpeech));

  const mixedSegments = [];
  
  for (let i = 0; i < template.segmentPatterns.length; i++) {
    const pattern = template.segmentPatterns[i];
    
    // Replace placeholders with actual Arabic words
    let text = pattern;
    
    // Add word variations - sometimes use different forms
    // For now, use the words directly embedded in the text
    
    // Build linkedWordIds based on which words appear in this segment
    const linkedWordIds = [];
    
    // Check for words from our list that might be in the text
    // The templates already have كَانَ, مِن, ذَٰلِكَ embedded
    // We need to link them to the actual word IDs
    
    // Find any embedded Arabic words and try to match them
    const arabicWordPattern = /[\u0600-\u06FF]+/g;
    const arabicWords = text.match(arabicWordPattern) || [];
    
    for (const aw of arabicWords) {
      // Find matching word in our list
      const match = words.find(w => 
        w.arabicText === aw || 
        w.arabicWithoutDiacritics === aw.replace(/[\u064B-\u065F\u0670]/g, '')
      );
      if (match && !linkedWordIds.includes(match.id)) {
        linkedWordIds.push(match.id);
      }
    }

    mixedSegments.push({
      id: uuidv4(),
      index: i,
      text,
      linkedWordIds,
      imageURL: null,
      culturalNote: null,
    });
  }

  // Create story document
  const now = admin.firestore.FieldValue.serverTimestamp();
  const storyId = uuidv4();
  
  const learnedWordIds = words.map(w => w.id);
  
  const allTags = new Set();
  words.forEach(w => {
    if (w.tags) w.tags.forEach(tag => allTags.add(tag));
  });

  const storyDescription = `A ${template.segmentPatterns.length}-segment narrative: ${template.theme}. Features ${words.length} essential Quranic words.`;
  const storyDescriptionArabic = `سرد من ${template.segmentPatterns.length} أجزاء: ${template.theme}.`;

  const storyDoc = {
    id: storyId,
    title: template.title,
    titleArabic: template.titleArabic,
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

  return storyDoc;
}

// ==================== WORD FETCHING ====================

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
 * Distribute words evenly across stories with randomization
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

async function fetchAndGroupWords(db) {
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

  console.log(`Found ${allWords.length} words`);

  const levels = {};
  for (let level = 1; level <= CONFIG.TOTAL_LEVELS; level++) {
    const startIdx = (level - 1) * CONFIG.WORDS_PER_LEVEL;
    const endIdx = Math.min(startIdx + CONFIG.WORDS_PER_LEVEL, allWords.length);
    levels[level] = allWords.slice(startIdx, endIdx);
    console.log(`Level ${level}: ${levels[level].length} words (ranks ${levels[level][0]?.rank || 'N/A'} - ${levels[level][levels[level].length - 1]?.rank || 'N/A'})`);
  }

  return levels;
}

/**
 * Select words that best match the template patterns
 */
function selectWordsForTemplate(template, levelWords) {
  // We need words like كَانَ (was), مِن (from), ذَٰلِكَ (that)
  // and other common words
  
  const selected = [];
  const addedIds = new Set();
  
  // Priority: Find كَانَ, مِن, ذَٰلِكَ first (they appear in templates)
  const priorityWords = ['كَانَ', 'مِن', 'ذَٰلِكَ', 'قَالَ', 'فِى'];
  
  for (const pw of priorityWords) {
    const found = levelWords.find(w => 
      w.arabicText === pw || w.arabicWithoutDiacritics === pw
    );
    if (found && !addedIds.has(found.id)) {
      selected.push(found);
      addedIds.add(found.id);
    }
  }
  
  // Fill remaining slots with other words from level
  for (const word of levelWords) {
    if (selected.length >= 6) break;
    if (!addedIds.has(word.id)) {
      selected.push(word);
      addedIds.add(word.id);
    }
  }
  
  return selected;
}

// ==================== MAIN ====================

async function generateManualStories() {
  console.log('========================================');
  console.log('Manual Story Generator (No AI Required)');
  console.log('========================================\n');
  console.log(`Configuration:`);
  console.log(`  - ${CONFIG.TOTAL_LEVELS} levels`);
  console.log(`  - ${CONFIG.STORIES_PER_LEVEL} stories per level`);
  console.log(`  - ${CONFIG.WORDS_PER_LEVEL} words per level`);
  console.log(`  - ~${(CONFIG.WORDS_PER_LEVEL / CONFIG.STORIES_PER_LEVEL).toFixed(1)} words per story (shuffled)`);
  console.log(`  - Total: ${CONFIG.TOTAL_LEVELS * CONFIG.STORIES_PER_LEVEL} stories\n`);

  console.log('Initializing Firebase...');
  const db = initializeFirebase();
  console.log('Firebase initialized\n');

  const levels = await fetchAndGroupWords(db);

  const totalStories = CONFIG.TOTAL_LEVELS * CONFIG.STORIES_PER_LEVEL;
  console.log(`\nWill generate ${totalStories} stories using templates\n`);

  let successCount = 0;

  for (let level = 1; level <= CONFIG.TOTAL_LEVELS; level++) {
    console.log(`\n========================================`);
    console.log(`Generating stories for LEVEL ${level}`);
    console.log(`========================================`);

    const levelWords = levels[level];
    if (levelWords.length === 0) {
      console.log(`  No words for level ${level}, skipping`);
      continue;
    }

    // Distribute words across stories (shuffled)
    const storyWordGroups = distributeWordsForLevel(levelWords, CONFIG.STORIES_PER_LEVEL);

    for (let i = 0; i < CONFIG.STORIES_PER_LEVEL; i++) {
      const storyNum = (level - 1) * CONFIG.STORIES_PER_LEVEL + i + 1;
      const template = STORY_TEMPLATES[i % STORY_TEMPLATES.length];
      const selectedWords = storyWordGroups[i];
      
      console.log(`\n[${storyNum}/${totalStories}] ${template.title}`);
      console.log(`  Words: ${selectedWords.map(w => w.arabicText).join(', ')} (${selectedWords.length} words)`);

      try {
        const storyDoc = generateStoryFromTemplate(template, selectedWords, level, i);
        
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
  console.log(`Success: ${successCount}/${totalStories} stories`);
  console.log('========================================');

  process.exit(0);
}

process.on('unhandledRejection', (error) => {
  console.error('Unhandled error:', error);
  process.exit(1);
});

generateManualStories().catch(console.error);
