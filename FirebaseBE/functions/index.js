/**
 * Arabic Stories Admin API
 * Firebase Functions with Express routing
 */

const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const functions = require('firebase-functions');
const express = require('express');
const cors = require('cors');

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();

// Collection references
const STORIES_COLLECTION = 'stories';
const ADMIN_LOGS_COLLECTION = 'admin_logs';
const WORDS_COLLECTION = 'words';

// Create Express app
const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

/**
 * Helper: Log admin actions
 */
async function logAdminAction(action, details, ip) {
  try {
    await db.collection(ADMIN_LOGS_COLLECTION).add({
      action,
      details,
      ip: ip || 'unknown',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Failed to log admin action:', error);
  }
}

/**
 * Helper: Convert story data to Firestore format
 */
function formatStoryForFirestore(storyData) {
  const now = new Date().toISOString();
  
  // Determine format (mixed for Level 1, bilingual for Level 2+)
  const format = storyData.format || 'bilingual';
  const difficultyLevel = Math.min(Math.max(parseInt(storyData.difficultyLevel) || 1, 1), 5);
  
  // Use mixed format for Level 1 if not explicitly set
  const finalFormat = format || (difficultyLevel === 1 ? 'mixed' : 'bilingual');
  
  const baseStory = {
    id: storyData.id || require('crypto').randomUUID(),
    title: storyData.title || '',
    titleArabic: storyData.titleArabic || null,
    storyDescription: storyData.storyDescription || '',
    storyDescriptionArabic: storyData.storyDescriptionArabic || null,
    author: storyData.author || 'Anonymous',
    format: finalFormat,
    difficultyLevel: difficultyLevel,
    category: storyData.category || 'general',
    tags: Array.isArray(storyData.tags) ? storyData.tags : [],
    coverImageURL: storyData.coverImageURL || null,
    audioNarrationURL: storyData.audioNarrationURL || null,
    isUserCreated: false,
    isDownloaded: false,
    downloadDate: null,
    sourceURL: storyData.sourceURL || null,
    readingProgress: 0,
    currentSegmentIndex: 0,
    completedWords: {},
    learnedWordIds: [],
    isBookmarked: false,
    totalReadingTime: 0,
    viewCount: 0,
    completionCount: 0,
    averageRating: null,
    createdAt: storyData.createdAt || now,
    updatedAt: now
  };
  
  // Handle words/vocabulary (used in both formats)
  baseStory.words = (storyData.words || []).map(word => ({
    id: word.id || require('crypto').randomUUID(),
    arabic: word.arabic || word.arabicText || '',
    english: word.english || word.englishMeaning || '',
    transliteration: word.transliteration || null,
    partOfSpeech: word.partOfSpeech || null,
    rootLetters: word.rootLetters || null,
    exampleSentence: word.exampleSentence || null,
    difficulty: word.difficulty || 1
  }));
  
  // Handle format-specific content
  if (finalFormat === 'mixed') {
    // Mixed format (Level 1): English text with embedded Arabic words
    baseStory.mixedSegments = (storyData.mixedSegments || []).map((seg, idx) => ({
      id: seg.id || require('crypto').randomUUID(),
      index: idx,
      contentParts: (seg.contentParts || []).map(part => ({
        id: part.id || require('crypto').randomUUID(),
        type: part.type || 'text', // 'text' or 'arabicWord'
        text: part.text || '',
        wordId: part.wordId || null,
        transliteration: part.transliteration || null
      })),
      imageURL: seg.imageURL || null,
      culturalNote: seg.culturalNote || null
    }));
    baseStory.segments = []; // Empty for mixed format
  } else {
    // Bilingual format (Level 2+): Full Arabic with English translation
    baseStory.segments = (storyData.segments || []).map((seg, idx) => ({
      id: seg.id || require('crypto').randomUUID(),
      index: idx,
      arabicText: seg.arabicText || '',
      englishText: seg.englishText || '',
      transliteration: seg.transliteration || null,
      audioStartTime: seg.audioStartTime || null,
      audioEndTime: seg.audioEndTime || null,
      wordTimings: seg.wordTimings || [],
      imageURL: seg.imageURL || null,
      culturalNote: seg.culturalNote || null,
      grammarNote: seg.grammarNote || null
    }));
    baseStory.mixedSegments = []; // Empty for bilingual format
  }
  
  // Grammar notes (optional, mainly for Level 2+)
  baseStory.grammarNotes = (storyData.grammarNotes || []).map(note => ({
    id: note.id || require('crypto').randomUUID(),
    title: note.title || '',
    explanation: note.explanation || '',
    exampleArabic: note.exampleArabic || '',
    exampleEnglish: note.exampleEnglish || '',
    ruleCategory: note.ruleCategory || 'general',
    createdAt: now
  }));
  
  return baseStory;
}

// ============================================
// ROUTES
// ============================================

// Health check
app.get('/', (req, res) => {
  res.json({ status: 'ok', message: 'Arabic Stories API' });
});

// List all stories
app.get('/api/stories', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const offset = parseInt(req.query.offset) || 0;
    const format = req.query.format; // Filter by format
    
    let query = db.collection(STORIES_COLLECTION)
      .orderBy('createdAt', 'desc')
      .limit(limit)
      .offset(offset);
    
    if (format) {
      query = query.where('format', '==', format);
    }
    
    const snapshot = await query.get();
    
    const stories = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    res.json({
      success: true,
      count: stories.length,
      stories: stories.map(s => ({
        id: s.id,
        title: s.title,
        titleArabic: s.titleArabic,
        author: s.author,
        format: s.format,
        difficultyLevel: s.difficultyLevel,
        category: s.category,
        segmentCount: s.format === 'mixed' 
          ? (s.mixedSegments?.length || 0) 
          : (s.segments?.length || 0),
        wordCount: s.words?.length || 0,
        createdAt: s.createdAt,
        updatedAt: s.updatedAt
      }))
    });
  } catch (error) {
    console.error('Error listing stories:', error);
    res.status(500).json({ error: error.message });
  }
});

// Create new story
app.post('/api/stories', async (req, res) => {
  try {
    const storyData = req.body;
    
    console.log('Received story data:', JSON.stringify(storyData, null, 2));
    
    // Check for field name variations
    const title = storyData.title || storyData.storyTitle || storyData.name;
    const description = storyData.storyDescription || storyData.description || storyData.desc || storyData.summary;
    
    if (!title || !description) {
      console.error('Missing required fields. Received:', Object.keys(storyData));
      res.status(400).json({ 
        error: 'Missing required fields: title and storyDescription are required',
        received: Object.keys(storyData),
        title: title || 'MISSING',
        description: description ? 'PRESENT' : 'MISSING'
      });
      return;
    }

    const formattedStory = formatStoryForFirestore(storyData);
    await db.collection(STORIES_COLLECTION).doc(formattedStory.id).set(formattedStory);
    
    await logAdminAction('CREATE_STORY', { 
      storyId: formattedStory.id, 
      title: formattedStory.title,
      format: formattedStory.format,
      difficultyLevel: formattedStory.difficultyLevel
    }, req.ip);
    
    res.status(201).json({
      success: true,
      message: 'Story created successfully',
      story: {
        id: formattedStory.id,
        title: formattedStory.title,
        format: formattedStory.format,
        segmentCount: formattedStory.format === 'mixed' 
          ? formattedStory.mixedSegments.length 
          : formattedStory.segments.length,
        wordCount: formattedStory.words.length
      }
    });
  } catch (error) {
    console.error('Error creating story:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get single story
app.get('/api/stories/:id', async (req, res) => {
  try {
    const doc = await db.collection(STORIES_COLLECTION).doc(req.params.id).get();
    
    if (!doc.exists) {
      res.status(404).json({ error: 'Story not found' });
      return;
    }
    
    res.json({
      success: true,
      story: { id: doc.id, ...doc.data() }
    });
  } catch (error) {
    console.error('Error getting story:', error);
    res.status(500).json({ error: error.message });
  }
});

// Update story
app.put('/api/stories/:id', async (req, res) => {
  try {
    const storyId = req.params.id;
    const storyData = req.body;
    
    const docRef = db.collection(STORIES_COLLECTION).doc(storyId);
    const doc = await docRef.get();
    
    if (!doc.exists) {
      res.status(404).json({ error: 'Story not found' });
      return;
    }

    const formattedStory = formatStoryForFirestore({
      ...storyData,
      id: storyId,
      createdAt: doc.data().createdAt
    });
    
    await docRef.update(formattedStory);
    await logAdminAction('UPDATE_STORY', { 
      storyId, 
      title: formattedStory.title,
      format: formattedStory.format 
    }, req.ip);
    
    res.json({
      success: true,
      message: 'Story updated successfully',
      story: { 
        id: storyId, 
        title: formattedStory.title,
        format: formattedStory.format
      }
    });
  } catch (error) {
    console.error('Error updating story:', error);
    res.status(500).json({ error: error.message });
  }
});

// Delete story
app.delete('/api/stories/:id', async (req, res) => {
  try {
    const storyId = req.params.id;
    
    const docRef = db.collection(STORIES_COLLECTION).doc(storyId);
    const doc = await docRef.get();
    
    if (!doc.exists) {
      res.status(404).json({ error: 'Story not found' });
      return;
    }

    await docRef.delete();
    await logAdminAction('DELETE_STORY', { storyId, title: doc.data().title }, req.ip);
    
    res.json({
      success: true,
      message: 'Story deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting story:', error);
    res.status(500).json({ error: error.message });
  }
});

// Validate story
app.post('/api/stories/validate', async (req, res) => {
  try {
    const storyData = req.body;
    const errors = [];
    const warnings = [];

    if (!storyData.title || storyData.title.trim().length < 2) {
      errors.push('Title is required and must be at least 2 characters');
    }
    if (!storyData.storyDescription || storyData.storyDescription.trim().length < 10) {
      errors.push('Description is required and must be at least 10 characters');
    }
    if (!storyData.author || storyData.author.trim().length < 1) {
      errors.push('Author is required');
    }

    if (!storyData.titleArabic) {
      warnings.push('Arabic title is recommended');
    }
    if (!storyData.storyDescriptionArabic) {
      warnings.push('Arabic description is recommended');
    }

    // Validate based on format
    const format = storyData.format || 'bilingual';
    
    if (format === 'mixed') {
      // Validate mixed format (Level 1)
      if (!storyData.mixedSegments || storyData.mixedSegments.length === 0) {
        errors.push('At least one mixed segment is required for Level 1 stories');
      } else {
        storyData.mixedSegments.forEach((seg, idx) => {
          if (!seg.contentParts || seg.contentParts.length === 0) {
            errors.push(`Segment ${idx + 1}: At least one content part is required`);
          }
        });
      }
    } else {
      // Validate bilingual format (Level 2+)
      if (!storyData.segments || storyData.segments.length === 0) {
        errors.push('At least one story segment is required');
      } else {
        storyData.segments.forEach((seg, idx) => {
          if (!seg.arabicText || seg.arabicText.trim().length === 0) {
            errors.push(`Segment ${idx + 1}: Arabic text is required`);
          }
          if (!seg.englishText || seg.englishText.trim().length === 0) {
            errors.push(`Segment ${idx + 1}: English text is required`);
          }
        });
      }
    }

    const difficulty = parseInt(storyData.difficultyLevel);
    if (isNaN(difficulty) || difficulty < 1 || difficulty > 5) {
      errors.push('Difficulty level must be between 1 and 5');
    }
    
    // Recommend mixed format for Level 1
    if (difficulty === 1 && format !== 'mixed') {
      warnings.push('Level 1 stories are recommended to use "mixed" format for vocabulary building');
    }

    res.json({
      success: errors.length === 0,
      valid: errors.length === 0,
      errors,
      warnings,
      summary: {
        title: storyData.title,
        format: format,
        segmentCount: format === 'mixed' 
          ? (storyData.mixedSegments?.length || 0)
          : (storyData.segments?.length || 0),
        wordCount: storyData.words?.length || 0,
        difficultyLevel: difficulty
      }
    });
  } catch (error) {
    console.error('Error validating story:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get categories
app.get('/api/categories', (req, res) => {
  const categories = [
    { value: 'general', label: 'General', icon: 'book' },
    { value: 'folktale', label: 'Folktale', icon: 'sparkles' },
    { value: 'history', label: 'History', icon: 'clock' },
    { value: 'science', label: 'Science', icon: 'atom' },
    { value: 'culture', label: 'Culture', icon: 'building' },
    { value: 'adventure', label: 'Adventure', icon: 'compass' },
    { value: 'mystery', label: 'Mystery', icon: 'question' },
    { value: 'romance', label: 'Romance', icon: 'heart' },
    { value: 'children', label: 'Children', icon: 'child' },
    { value: 'religious', label: 'Religious', icon: 'star' },
    { value: 'poetry', label: 'Poetry', icon: 'quote' },
    { value: 'modern', label: 'Modern', icon: 'newspaper' }
  ];

  res.json({ success: true, categories });
});

// Seed sample stories
app.post('/api/seed', async (req, res) => {
  try {
    const sampleStories = [
      {
        title: "The Friendly Cat",
        titleArabic: "القطة الودودة",
        storyDescription: "A simple story about a friendly cat who helps a lost bird find its way home.",
        storyDescriptionArabic: "قصة بسيطة عن قطة ودودة تساعد عصفوراً ضالاً في إيجاد طريقه إلى المنزل.",
        author: "Hikaya Test",
        format: "bilingual",
        difficultyLevel: 2,
        category: "children",
        tags: ["animals", "friendship", "helping"],
        coverImageURL: "https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=800",
        segments: [
          {
            arabicText: "في يوم مشمس، كانت هناك قطة صغيرة اسمها لولو.",
            englishText: "On a sunny day, there was a small cat named Lulu.",
            transliteration: "Fī yawm mushmis, kānat hunā qiṭṭa ṣaghīra ismuhā Lūlū."
          },
          {
            arabicText: "سمعت لولو صوتاً ضعيفاً قادماً من الشجرة.",
            englishText: "Lulu heard a weak voice coming from the tree.",
            transliteration: "Samiʿat Lūlū ṣawtan ḍaʿīfan qādiman min al-shajara."
          }
        ]
      }
    ];

    const results = [];
    for (const story of sampleStories) {
      const formatted = formatStoryForFirestore(story);
      await db.collection(STORIES_COLLECTION).doc(formatted.id).set(formatted);
      results.push({ id: formatted.id, title: formatted.title, format: formatted.format });
    }

    res.json({
      success: true,
      message: `${results.length} stories seeded successfully`,
      stories: results
    });
  } catch (error) {
    console.error('Error seeding stories:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Helper: Convert generic word data to Firestore format
 */
function formatWordForFirestore(wordData) {
  const now = new Date().toISOString();
  
  return {
    id: wordData.id || require('crypto').randomUUID(),
    arabic: wordData.arabic || wordData.arabicText || '',
    english: wordData.english || wordData.englishMeaning || '',
    transliteration: wordData.transliteration || null,
    partOfSpeech: wordData.partOfSpeech || null,
    rootLetters: wordData.rootLetters || null,
    exampleSentence: wordData.exampleSentence || null,
    exampleSentenceTranslation: wordData.exampleSentenceTranslation || null,
    difficulty: Math.min(Math.max(parseInt(wordData.difficulty) || 1, 1), 5),
    tags: Array.isArray(wordData.tags) ? wordData.tags : [],
    category: wordData.category || 'general',
    isGeneric: true,
    createdAt: wordData.createdAt || now,
    updatedAt: now
  };
}

// ============================================
// GENERIC WORDS ROUTES
// ============================================

// List all generic words
app.get('/api/words', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const offset = parseInt(req.query.offset) || 0;
    const category = req.query.category;
    const difficulty = req.query.difficulty;
    const search = req.query.search;
    
    let query = db.collection(WORDS_COLLECTION).orderBy('createdAt', 'desc');
    
    if (category) {
      query = query.where('category', '==', category);
    }
    if (difficulty) {
      query = query.where('difficulty', '==', parseInt(difficulty));
    }
    
    const snapshot = await query.limit(limit).offset(offset).get();
    let words = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    
    // Simple search filter (client-side for now)
    if (search) {
      const searchLower = search.toLowerCase();
      words = words.filter(w => 
        w.arabic?.toLowerCase().includes(searchLower) ||
        w.english?.toLowerCase().includes(searchLower) ||
        w.transliteration?.toLowerCase().includes(searchLower)
      );
    }
    
    res.json({
      success: true,
      count: words.length,
      words
    });
  } catch (error) {
    console.error('Error listing words:', error);
    res.status(500).json({ error: error.message });
  }
});

// Create new generic word
app.post('/api/words', async (req, res) => {
  try {
    const wordData = req.body;
    
    if (!wordData.arabic && !wordData.arabicText) {
      res.status(400).json({ 
        error: 'Missing required fields: arabic is required' 
      });
      return;
    }
    if (!wordData.english && !wordData.englishMeaning) {
      res.status(400).json({ 
        error: 'Missing required fields: english is required' 
      });
      return;
    }

    const formattedWord = formatWordForFirestore(wordData);
    await db.collection(WORDS_COLLECTION).doc(formattedWord.id).set(formattedWord);
    
    await logAdminAction('CREATE_WORD', { wordId: formattedWord.id, arabic: formattedWord.arabic }, req.ip);
    
    res.status(201).json({
      success: true,
      message: 'Word created successfully',
      word: formattedWord
    });
  } catch (error) {
    console.error('Error creating word:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get single word
app.get('/api/words/:id', async (req, res) => {
  try {
    const doc = await db.collection(WORDS_COLLECTION).doc(req.params.id).get();
    
    if (!doc.exists) {
      res.status(404).json({ error: 'Word not found' });
      return;
    }
    
    res.json({
      success: true,
      word: { id: doc.id, ...doc.data() }
    });
  } catch (error) {
    console.error('Error getting word:', error);
    res.status(500).json({ error: error.message });
  }
});

// Update word
app.put('/api/words/:id', async (req, res) => {
  try {
    const wordId = req.params.id;
    const wordData = req.body;
    
    const docRef = db.collection(WORDS_COLLECTION).doc(wordId);
    const doc = await docRef.get();
    
    if (!doc.exists) {
      res.status(404).json({ error: 'Word not found' });
      return;
    }

    const formattedWord = formatWordForFirestore({
      ...wordData,
      id: wordId,
      createdAt: doc.data().createdAt
    });
    
    await docRef.update(formattedWord);
    await logAdminAction('UPDATE_WORD', { wordId, arabic: formattedWord.arabic }, req.ip);
    
    res.json({
      success: true,
      message: 'Word updated successfully',
      word: formattedWord
    });
  } catch (error) {
    console.error('Error updating word:', error);
    res.status(500).json({ error: error.message });
  }
});

// Delete word
app.delete('/api/words/:id', async (req, res) => {
  try {
    const wordId = req.params.id;
    
    const docRef = db.collection(WORDS_COLLECTION).doc(wordId);
    const doc = await docRef.get();
    
    if (!doc.exists) {
      res.status(404).json({ error: 'Word not found' });
      return;
    }

    await docRef.delete();
    await logAdminAction('DELETE_WORD', { wordId, arabic: doc.data().arabic }, req.ip);
    
    res.json({
      success: true,
      message: 'Word deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting word:', error);
    res.status(500).json({ error: error.message });
  }
});

// Bulk import words
app.post('/api/words/bulk', async (req, res) => {
  try {
    const { words } = req.body;
    
    if (!Array.isArray(words) || words.length === 0) {
      res.status(400).json({ error: 'words array is required and must not be empty' });
      return;
    }

    const results = [];
    const errors = [];
    
    for (const wordData of words) {
      try {
        if ((!wordData.arabic && !wordData.arabicText) || (!wordData.english && !wordData.englishMeaning)) {
          errors.push({ wordData, error: 'Missing arabic or english' });
          continue;
        }
        
        const formattedWord = formatWordForFirestore(wordData);
        await db.collection(WORDS_COLLECTION).doc(formattedWord.id).set(formattedWord);
        results.push({ id: formattedWord.id, arabic: formattedWord.arabic });
      } catch (err) {
        errors.push({ wordData, error: err.message });
      }
    }
    
    await logAdminAction('BULK_IMPORT_WORDS', { count: results.length }, req.ip);
    
    res.status(201).json({
      success: true,
      message: `${results.length} words imported successfully`,
      imported: results,
      errors: errors.length > 0 ? errors : undefined
    });
  } catch (error) {
    console.error('Error bulk importing words:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get word categories (for filtering)
app.get('/api/words/categories/list', (req, res) => {
  const categories = [
    { value: 'general', label: 'General' },
    { value: 'noun', label: 'Noun' },
    { value: 'verb', label: 'Verb' },
    { value: 'adjective', label: 'Adjective' },
    { value: 'adverb', label: 'Adverb' },
    { value: 'phrase', label: 'Phrase' },
    { value: 'greeting', label: 'Greeting' },
    { value: 'number', label: 'Number' },
    { value: 'time', label: 'Time' },
    { value: 'food', label: 'Food' },
    { value: 'travel', label: 'Travel' },
    { value: 'business', label: 'Business' }
  ];
  
  res.json({ success: true, categories });
});

// Get parts of speech
app.get('/api/words/parts-of-speech', (req, res) => {
  const partsOfSpeech = [
    { value: 'noun', label: 'Noun' },
    { value: 'verb', label: 'Verb' },
    { value: 'adjective', label: 'Adjective' },
    { value: 'adverb', label: 'Adverb' },
    { value: 'pronoun', label: 'Pronoun' },
    { value: 'preposition', label: 'Preposition' },
    { value: 'conjunction', label: 'Conjunction' },
    { value: 'interjection', label: 'Interjection' },
    { value: 'particle', label: 'Particle' }
  ];
  
  res.json({ success: true, partsOfSpeech });
});

// Export the Express app as a Firebase Function
exports.api = functions.https.onRequest(app);
