/**
 * Arabic Stories Admin API
 * Firebase Functions with Express routing
 */

const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const functions = require('firebase-functions');
const express = require('express');
const cors = require('cors');
const nodemailer = require('nodemailer');
const multer = require('multer');
const Busboy = require('busboy');

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();
const storage = getStorage();
const upload = multer({ 
  storage: multer.memoryStorage(), 
  limits: { 
    fileSize: 20 * 1024 * 1024, // 20MB
    fieldSize: 1024 * 1024, // 1MB for form fields
    fields: 10, // Maximum 10 form fields
    files: 1 // Maximum 1 file
  },
  fileFilter: (req, file, cb) => {
    console.log('MULTER FILE FILTER:', {
      fieldname: file.fieldname,
      originalname: file.originalname,
      mimetype: file.mimetype
    });
    
    // Accept audio files
    if (file.mimetype.startsWith('audio/')) {
      cb(null, true);
    } else {
      cb(new Error(`Invalid file type: ${file.mimetype}. Only audio files are allowed.`));
    }
  }
});

// Collection references
const STORIES_COLLECTION = 'stories';
const ADMIN_LOGS_COLLECTION = 'admin_logs';
const USER_COMPLETIONS_COLLECTION = 'user_completions';

// Email configuration
const EMAIL_CONFIG = {
  service: 'gmail',
  auth: {
    user: 'volutiontechnologies@gmail.com',
    pass: 'tneh ndls rjjq pffm'
  }
};

const NOTIFICATION_EMAIL = 'volutiontechnologies@gmail.com';

// Create email transporter
let emailTransporter = null;
try {
  emailTransporter = nodemailer.createTransport(EMAIL_CONFIG);
  console.log('Email transporter initialized successfully');
} catch (error) {
  console.error('Failed to initialize email transporter:', error);
}

// Create Express app
const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

/**
 * Send email notification
 */
async function sendEmail(subject, html) {
  if (!emailTransporter) {
    console.error('Email transporter not configured');
    return false;
  }
  
  try {
    await emailTransporter.sendMail({
      from: `"Arabic Stories" <${EMAIL_CONFIG.auth.user}>`,
      to: NOTIFICATION_EMAIL,
      subject: subject,
      html: html
    });
    console.log('Email sent successfully:', subject);
    return true;
  } catch (error) {
    console.error('Failed to send email:', error);
    return false;
  }
}

/**
 * Helper: Log admin actions
 */
async function logAdminAction(action, details, ip) {
  try {
    await db.collection(ADMIN_LOGS_COLLECTION).add({
      action,
      details,
      ip: ip || 'unknown',
      timestamp: new Date()
    });
  } catch (error) {
    console.error('Failed to log admin action:', error);
  }
}

/**
 * Helper: Convert story data to Firestore format
 */
function formatStoryForFirestore(storyData) {
  const now = new Date();
  
  // Determine format (mixed for Level 1, bilingual for Level 2+)
  const format = storyData.format || 'bilingual';
  const difficultyLevel = Math.min(Math.max(parseInt(storyData.difficultyLevel) || 1, 1), 400);
  
  // Use mixed format for Level 1 if not explicitly set
  const finalFormat = format || (difficultyLevel === 1 ? 'mixed' : 'bilingual');
  
  // Preserve existing ID or generate new one only for new stories
  const storyId = storyData.id && storyData.id.trim() !== '' 
    ? storyData.id 
    : require('crypto').randomUUID();
  
  const baseStory = {
    id: storyId,
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
  
  // Handle words/vocabulary - now references quran_words collection
  baseStory.words = (storyData.words || []).map(word => ({
    id: word.id || require('crypto').randomUUID(),
    arabicText: word.arabicText || word.arabic || '',
    arabicWithoutDiacritics: word.arabicWithoutDiacritics || word.arabic || '',
    buckwalter: word.buckwalter || word.transliteration || null,
    englishMeaning: word.englishMeaning || word.english || '',
    root: {
      arabic: word.root?.arabic || word.rootLetters || null,
      transliteration: word.root?.transliteration || null
    },
    morphology: {
      partOfSpeech: word.morphology?.partOfSpeech || word.partOfSpeech || null,
      posDescription: word.morphology?.posDescription || null,
      lemma: word.morphology?.lemma || null,
      form: word.morphology?.form || null,
      tense: word.morphology?.tense || null,
      gender: word.morphology?.gender || null,
      number: word.morphology?.number || null,
      grammaticalCase: word.morphology?.grammaticalCase || null,
      passive: word.morphology?.passive || false,
      breakdown: word.morphology?.breakdown || null
    },
    rank: word.rank || null,
    occurrenceCount: word.occurrenceCount || 0
  }));
  
  // Handle format-specific content
  if (finalFormat === 'mixed') {
    // Mixed format (Level 1): Simple text segments - admin links Arabic words separately
    baseStory.mixedSegments = (storyData.mixedSegments || []).map((seg, idx) => ({
      id: seg.id || require('crypto').randomUUID(),
      index: idx,
      text: seg.text || '',  // Plain text - admin will link Arabic words separately
      imageURL: seg.imageURL || null,
      culturalNote: seg.culturalNote || null,
      linkedWordIds: seg.linkedWordIds || []  // IDs of Arabic words linked by admin
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

// Debug endpoint to test audio upload route
app.get('/api/quran-words/:id/audio/test', (req, res) => {
  res.json({ 
    status: 'ok', 
    message: 'Audio upload route is reachable',
    wordId: req.params.id,
    timestamp: new Date().toISOString()
  });
});

// Test POST endpoint without file upload
app.post('/api/quran-words/:id/audio/test', (req, res) => {
  res.json({ 
    status: 'ok', 
    message: 'POST audio upload route is reachable',
    wordId: req.params.id,
    hasBody: !!req.body,
    contentType: req.headers['content-type'],
    timestamp: new Date().toISOString()
  });
});

// Test the actual audio upload endpoint without multer
app.post('/api/quran-words/:id/audio/simple', async (req, res) => {
  try {
    console.log('SIMPLE AUDIO TEST - No multer involved');
    console.log('Word ID:', req.params.id);
    console.log('Content-Type:', req.headers['content-type']);
    console.log('Has body:', !!req.body);
    
    res.json({
      success: true,
      message: 'Simple audio endpoint reached successfully',
      wordId: req.params.id,
      contentType: req.headers['content-type'],
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error in simple audio test:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      details: 'Simple audio test failed'
    });
  }
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
    
    console.log('========================================');
    console.log('CREATE STORY API CALLED');
    console.log('Received body:', JSON.stringify(storyData, null, 2));
    console.log('========================================');
    
    // Check for field name variations (handle both naming conventions)
    const title = storyData.title || storyData.storyTitle || storyData.name || '';
    const description = storyData.storyDescription || storyData.description || storyData.desc || storyData.summary || '';
    const author = storyData.author || storyData.authorName || 'Anonymous';
    
    console.log('Extracted fields:');
    console.log('  title:', title || '(EMPTY)');
    console.log('  description:', description ? '(PRESENT)' : '(EMPTY)');
    console.log('  author:', author);
    
    if (!title || title.trim() === '') {
      console.error('ERROR: Missing or empty title');
      res.status(400).json({ 
        error: 'Missing required field: title is required',
        receivedFields: Object.keys(storyData),
        receivedTitle: storyData.title,
        hint: 'Make sure JSON has a "title" field'
      });
      return;
    }
    
    if (!description || description.trim() === '') {
      console.error('ERROR: Missing or empty description');
      res.status(400).json({ 
        error: 'Missing required field: storyDescription is required',
        receivedFields: Object.keys(storyData),
        hint: 'Make sure JSON has a "storyDescription" field (or "description" or "desc")'
      });
      return;
    }

    const formattedStory = formatStoryForFirestore(storyData);
    
    console.log('Formatted story for Firestore:');
    console.log('  id:', formattedStory.id);
    console.log('  title:', formattedStory.title);
    console.log('  format:', formattedStory.format);
    console.log('  difficultyLevel:', formattedStory.difficultyLevel);
    console.log('  mixedSegments count:', formattedStory.mixedSegments?.length || 0);
    console.log('  segments count:', formattedStory.segments?.length || 0);
    console.log('  words count:', formattedStory.words?.length || 0);
    
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
    res.status(500).json({ error: error.message, stack: error.stack });
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
    
    console.log('UPDATE STORY REQUEST:', {
      paramId: storyId,
      bodyId: storyData.id,
      title: storyData.title
    });
    
    const docRef = db.collection(STORIES_COLLECTION).doc(storyId);
    const doc = await docRef.get();
    
    if (!doc.exists) {
      res.status(404).json({ error: 'Story not found' });
      return;
    }

    const dataToFormat = {
      ...storyData,
      id: storyId,
      createdAt: doc.data().createdAt
    };
    console.log('Data to format:', { id: dataToFormat.id, title: dataToFormat.title });
    
    const formattedStory = formatStoryForFirestore(dataToFormat);
    console.log('Formatted story ID:', formattedStory.id);
    
    // Remove id from update data since we're updating by doc reference
    const { id, ...updateData } = formattedStory;
    console.log('Updating doc:', storyId, 'with data id:', id);
    
    await docRef.update(updateData);
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
      // Validate mixed format (Level 1) - simplified: just text field
      if (!storyData.mixedSegments || storyData.mixedSegments.length === 0) {
        errors.push('At least one mixed segment is required for Level 1 stories');
      } else {
        storyData.mixedSegments.forEach((seg, idx) => {
          if (!seg.text || seg.text.trim().length === 0) {
            errors.push(`Segment ${idx + 1}: Text content is required`);
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
    if (isNaN(difficulty) || difficulty < 1 || difficulty > 400) {
      errors.push('Difficulty level must be between 1 and 400');
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
        author: "Arabicly",
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

// ============================================
// QURAN WORDS ROUTES (quran_words collection)
// ============================================

// List all quran words
app.get('/api/quran-words', async (req, res) => {
  try {
    let limit = parseInt(req.query.limit) || 50;
    const offset = parseInt(req.query.offset) || 0;
    const pos = req.query.pos;
    const form = req.query.form;
    const sort = req.query.sort || 'rank';
    const root = req.query.root;
    
    // Cap limit at 20000 to prevent performance issues
    // (quran_words has ~19,000 documents)
    if (limit > 20000) {
      limit = 20000;
    }
    
    let query = db.collection('quran_words');
    
    // Apply filters
    if (pos) {
      query = query.where('morphology.partOfSpeech', '==', pos);
    }
    if (form) {
      query = query.where('morphology.form', '==', form);
    }
    if (root) {
      query = query.where('root.arabic', '==', root);
    }
    
    // Apply sorting
    if (sort === 'occurrenceCount') {
      query = query.orderBy('occurrenceCount', 'desc');
    } else if (sort === 'arabicText') {
      query = query.orderBy('arabicText');
    } else {
      query = query.orderBy('rank');
    }
    
    const [snapshot, countSnapshot] = await Promise.all([
      query.limit(limit).offset(offset).get(),
      db.collection('quran_words').count().get()
    ]);
    const words = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    const total = countSnapshot.data().count;

    res.json({
      success: true,
      count: words.length,
      total,
      words
    });
  } catch (error) {
    console.error('Error listing quran words:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get single quran word
app.get('/api/quran-words/:id', async (req, res) => {
  try {
    const doc = await db.collection('quran_words').doc(req.params.id).get();
    
    if (!doc.exists) {
      res.status(404).json({ error: 'Word not found' });
      return;
    }
    
    res.json({
      success: true,
      word: { id: doc.id, ...doc.data() }
    });
  } catch (error) {
    console.error('Error getting quran word:', error);
    res.status(500).json({ error: error.message });
  }
});

// Create new quran word
app.post('/api/quran-words', async (req, res) => {
  try {
    const wordData = req.body;

    if (!wordData.arabicText || !wordData.englishMeaning) {
      res.status(400).json({ error: 'arabicText and englishMeaning are required' });
      return;
    }

    const now = new Date();
    const wordId = require('crypto').randomUUID();

    const newWord = {
      id: wordId,
      arabicText: wordData.arabicText.trim(),
      arabicWithoutDiacritics: wordData.arabicWithoutDiacritics?.trim() || wordData.arabicText.trim(),
      buckwalter: wordData.buckwalter?.trim() || null,
      englishMeaning: wordData.englishMeaning.trim(),
      exampleArabic: wordData.exampleArabic?.trim() || null,
      exampleEnglish: wordData.exampleEnglish?.trim() || null,
      audioURL: null,
      root: {
        arabic: wordData.root?.arabic?.trim() || null,
        transliteration: wordData.root?.transliteration?.trim() || null,
        meaning: wordData.root?.meaning?.trim() || null
      },
      morphology: {
        partOfSpeech: wordData.morphology?.partOfSpeech || null,
        posDescription: wordData.morphology?.posDescription?.trim() || null,
        lemma: wordData.morphology?.lemma?.trim() || null,
        form: wordData.morphology?.form || null,
        tense: wordData.morphology?.tense || null,
        gender: wordData.morphology?.gender || null,
        number: wordData.morphology?.number || null,
        grammaticalCase: wordData.morphology?.grammaticalCase || null,
        state: wordData.morphology?.state || null,
        passive: wordData.morphology?.passive || false,
        breakdown: wordData.morphology?.breakdown?.trim() || null
      },
      rank: wordData.rank || null,
      occurrenceCount: wordData.occurrenceCount || 0,
      tags: Array.isArray(wordData.tags) ? wordData.tags : [],
      notes: wordData.notes?.trim() || null,
      createdAt: now,
      updatedAt: now
    };

    await db.collection('quran_words').doc(wordId).set(newWord);
    await logAdminAction('CREATE_WORD', { wordId, arabicText: newWord.arabicText }, req.ip);

    res.status(201).json({
      success: true,
      message: 'Word created successfully',
      word: newWord
    });
  } catch (error) {
    console.error('Error creating quran word:', error);
    res.status(500).json({ error: error.message });
  }
});

// Update quran word
app.put('/api/quran-words/:id', async (req, res) => {
  try {
    const wordId = req.params.id;
    const wordData = req.body;

    const docRef = db.collection('quran_words').doc(wordId);
    const doc = await docRef.get();

    if (!doc.exists) {
      res.status(404).json({ error: 'Word not found' });
      return;
    }

    if (!wordData.arabicText || !wordData.englishMeaning) {
      res.status(400).json({ error: 'arabicText and englishMeaning are required' });
      return;
    }

    const updateData = {
      arabicText: wordData.arabicText.trim(),
      arabicWithoutDiacritics: wordData.arabicWithoutDiacritics?.trim() || wordData.arabicText.trim(),
      buckwalter: wordData.buckwalter?.trim() || null,
      englishMeaning: wordData.englishMeaning.trim(),
      exampleArabic: wordData.exampleArabic?.trim() || null,
      exampleEnglish: wordData.exampleEnglish?.trim() || null,
      root: {
        arabic: wordData.root?.arabic?.trim() || null,
        transliteration: wordData.root?.transliteration?.trim() || null,
        meaning: wordData.root?.meaning?.trim() || null
      },
      morphology: {
        partOfSpeech: wordData.morphology?.partOfSpeech || null,
        posDescription: wordData.morphology?.posDescription?.trim() || null,
        lemma: wordData.morphology?.lemma?.trim() || null,
        form: wordData.morphology?.form || null,
        tense: wordData.morphology?.tense || null,
        gender: wordData.morphology?.gender || null,
        number: wordData.morphology?.number || null,
        grammaticalCase: wordData.morphology?.grammaticalCase || null,
        state: wordData.morphology?.state || null,
        passive: wordData.morphology?.passive || false,
        breakdown: wordData.morphology?.breakdown?.trim() || null
      },
      rank: wordData.rank || null,
      occurrenceCount: wordData.occurrenceCount || 0,
      tags: Array.isArray(wordData.tags) ? wordData.tags : [],
      notes: wordData.notes?.trim() || null,
      updatedAt: new Date()
    };

    await docRef.update(updateData);
    await logAdminAction('UPDATE_QURAN_WORD', { wordId, arabicText: updateData.arabicText }, req.ip);

    res.json({
      success: true,
      message: 'Word updated successfully',
      word: { id: wordId, ...updateData }
    });
  } catch (error) {
    console.error('Error updating quran word:', error);
    res.status(500).json({ error: error.message });
  }
});

// Search quran words by Arabic text
app.get('/api/quran-words/search/:text', async (req, res) => {
  try {
    const searchText = req.params.text;
    const limit = parseInt(req.query.limit) || 20;
    
    // Search by arabicText (with diacritics) or arabicWithoutDiacritics
    const snapshot = await db.collection('quran_words')
      .where('arabicWithoutDiacritics', '>=', searchText)
      .where('arabicWithoutDiacritics', '<=', searchText + '\uf8ff')
      .limit(limit)
      .get();
    
    const words = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    
    res.json({
      success: true,
      count: words.length,
      words
    });
  } catch (error) {
    console.error('Error searching quran words:', error);
    res.status(500).json({ error: error.message });
  }
});

// Upload audio for a quran word - Using busboy with rawBody (Firebase Functions compatible)
app.post('/api/quran-words/:id/audio', async (req, res) => {
  try {
    const wordId = req.params.id;
    
    console.log('========================================');
    console.log('AUDIO UPLOAD REQUEST RECEIVED (busboy+rawBody)');
    console.log('Word ID:', wordId);
    console.log('Content-Type:', req.headers['content-type']);
    console.log('Has rawBody:', !!req.rawBody);
    console.log('rawBody length:', req.rawBody ? req.rawBody.length : 0);
    console.log('========================================');
    
    if (!wordId || wordId.trim() === '') {
      console.error('ERROR: No word ID provided');
      return res.status(400).json({ error: 'Word ID is required' });
    }

    // Check if rawBody is available (Firebase Functions provides this)
    if (!req.rawBody) {
      console.error('ERROR: No rawBody available in request');
      return res.status(400).json({ error: 'No audio file data provided' });
    }

    // Use busboy to parse the multipart form data from rawBody
    const parsedFile = await new Promise((resolve, reject) => {
      const busboy = Busboy({ 
        headers: req.headers,
        limits: {
          fileSize: 20 * 1024 * 1024, // 20MB limit
          files: 1 // Only 1 file
        }
      });
      
      let fileBuffer = Buffer.alloc(0);
      let fileInfo = null;
      
      busboy.on('file', (fieldname, file, info) => {
        console.log('Busboy file event:', {
          fieldname,
          filename: info.filename,
          mimeType: info.mimeType
        });
        
        fileInfo = {
          fieldname,
          originalname: info.filename,
          mimetype: info.mimeType
        };
        
        const chunks = [];
        
        file.on('data', (data) => {
          chunks.push(data);
        });
        
        file.on('end', () => {
          fileBuffer = Buffer.concat(chunks);
          console.log('File received, size:', fileBuffer.length);
        });
      });
      
      busboy.on('finish', () => {
        console.log('Busboy finished parsing');
        if (fileInfo) {
          resolve({
            ...fileInfo,
            buffer: fileBuffer,
            size: fileBuffer.length
          });
        } else {
          resolve(null);
        }
      });
      
      busboy.on('error', (error) => {
        console.error('Busboy error:', error);
        reject(error);
      });
      
      // Use rawBody instead of piping the request (Firebase Functions specific)
      busboy.end(req.rawBody);
    });

    if (!parsedFile) {
      console.error('ERROR: No audio file found in form data');
      return res.status(400).json({ error: 'No audio file data provided' });
    }

    console.log('File upload details:', {
      originalName: parsedFile.originalname,
      mimeType: parsedFile.mimetype,
      size: parsedFile.size,
      bufferLength: parsedFile.buffer.length
    });

    const contentType = parsedFile.mimetype;
    const fileBuffer = parsedFile.buffer;
    const originalFileName = parsedFile.originalname;

    // Validate content type
    if (!contentType || !contentType.startsWith('audio/')) {
      console.error('ERROR: Invalid content type:', contentType);
      return res.status(400).json({ 
        error: `Content must be audio type. Received: ${contentType}` 
      });
    }

    // Validate file size
    if (parsedFile.size > 20 * 1024 * 1024) { // 20MB limit
      console.error('ERROR: File too large:', parsedFile.size);
      return res.status(400).json({ 
        error: `File size must be less than 20MB. Received: ${(parsedFile.size / 1024 / 1024).toFixed(2)}MB` 
      });
    }

    if (!fileBuffer || fileBuffer.length === 0) {
      console.error('ERROR: File buffer is empty');
      return res.status(400).json({ error: 'Audio file data is empty' });
    }

    console.log('File buffer created successfully:', {
      size: fileBuffer.length,
      type: typeof fileBuffer,
      isBuffer: Buffer.isBuffer(fileBuffer)
    });

    // Check if word exists
    console.log('Checking if word exists in database...');
    const docRef = db.collection('quran_words').doc(wordId);
    const doc = await docRef.get();
    if (!doc.exists) {
      console.error('ERROR: Word not found in database:', wordId);
      return res.status(404).json({ error: 'Word not found' });
    }

    console.log('Word found in database:', {
      id: doc.id,
      arabicText: doc.data().arabicText
    });

    // Get Firebase Storage bucket
    console.log('Initializing Firebase Storage...');
    const bucket = storage.bucket();
    
    if (!bucket) {
      console.error('ERROR: Could not initialize Firebase Storage bucket');
      return res.status(500).json({ error: 'Storage service unavailable' });
    }

    const storageFileName = `word-audio/${wordId}.mp3`;
    const file = bucket.file(storageFileName);
    console.log('Storage file path:', storageFileName);
    
    console.log('Using content type for storage:', contentType);

    console.log('Uploading to Firebase Storage...');
    
    try {
      await file.save(fileBuffer, {
        metadata: { 
          contentType: contentType,
          cacheControl: 'public, max-age=3600'
        }
      });
      console.log('File uploaded to storage successfully');
    } catch (storageError) {
      console.error('ERROR: Failed to upload to storage:', storageError);
      return res.status(500).json({ 
        error: 'Failed to upload file to storage',
        details: storageError.message
      });
    }

    console.log('Making file public...');
    try {
      await file.makePublic();
      console.log('File made public successfully');
    } catch (publicError) {
      console.error('ERROR: Failed to make file public:', publicError);
      return res.status(500).json({ 
        error: 'Failed to make file public',
        details: publicError.message
      });
    }

    const bucketName = bucket.name;
    const audioURL = `https://storage.googleapis.com/${bucketName}/${storageFileName}`;
    console.log('Generated audio URL:', audioURL);

    console.log('Updating Firestore with audio URL...');
    try {
      await docRef.update({ 
        audioURL: audioURL, 
        updatedAt: new Date() 
      });
      console.log('Firestore updated successfully');
    } catch (firestoreError) {
      console.error('ERROR: Failed to update Firestore:', firestoreError);
      return res.status(500).json({ 
        error: 'Failed to update database',
        details: firestoreError.message
      });
    }

    // Log admin action
    try {
      await logAdminAction('UPLOAD_WORD_AUDIO', { 
        wordId, 
        fileName: originalFileName,
        fileSize: fileBuffer.length,
        contentType: contentType,
        audioURL: audioURL
      }, req.ip);
    } catch (logError) {
      console.error('WARNING: Failed to log admin action:', logError);
      // Don't fail the request for logging issues
    }

    console.log('Audio upload completed successfully');
    console.log('========================================');
    
    res.json({ 
      success: true, 
      audioURL: audioURL,
      message: `Audio uploaded successfully (${(fileBuffer.length / 1024).toFixed(1)} KB)`,
      method: 'busboy_upload'
    });
    
  } catch (error) {
    console.error('========================================');
    console.error('CRITICAL ERROR in audio upload:', error);
    console.error('Error stack:', error.stack);
    console.error('Error details:', {
      name: error.name,
      message: error.message,
      code: error.code
    });
    console.error('========================================');
    
    res.status(500).json({ 
      success: false,
      error: error.message || 'Internal server error during audio upload',
      details: 'Check server logs for detailed error information',
      timestamp: new Date().toISOString()
    });
  }
});

// Delete audio for a quran word
app.delete('/api/quran-words/:id/audio', async (req, res) => {
  try {
    const wordId = req.params.id;

    const docRef = db.collection('quran_words').doc(wordId);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: 'Word not found' });
      return;
    }

    const bucket = storage.bucket();
    const file = bucket.file(`word-audio/${wordId}.mp3`);
    await file.delete().catch(() => {}); // ignore if file doesn't exist

    await docRef.update({ audioURL: null, updatedAt: new Date() });

    res.json({ success: true, message: 'Audio deleted' });
  } catch (error) {
    console.error('Error deleting word audio:', error);
    res.status(500).json({ error: error.message });
  }
});

// Delete quran word
app.delete('/api/quran-words/:id', async (req, res) => {
  try {
    const wordId = req.params.id;

    const docRef = db.collection('quran_words').doc(wordId);
    const doc = await docRef.get();
    if (!doc.exists) {
      res.status(404).json({ error: 'Word not found' });
      return;
    }

    const wordData = doc.data();

    // Delete associated audio file if it exists
    if (wordData.audioURL) {
      const bucket = storage.bucket();
      const file = bucket.file(`word-audio/${wordId}.mp3`);
      await file.delete().catch(() => {}); // ignore if file doesn't exist
    }

    // Delete the word document
    await docRef.delete();
    await logAdminAction('DELETE_WORD', { 
      wordId, 
      arabicText: wordData.arabicText,
      englishMeaning: wordData.englishMeaning
    }, req.ip);

    res.json({
      success: true,
      message: 'Word deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting word:', error);
    res.status(500).json({ error: error.message });
  }
});

// ============================================
// USER COMPLETION TRACKING ROUTES
// ============================================

/**
 * Track story completion
 * POST /api/completions/story
 * Body: { userId, userName, userEmail, storyId, storyTitle, difficultyLevel, completedAt }
 */
app.post('/api/completions/story', async (req, res) => {
  try {
    const { userId, userName, userEmail, storyId, storyTitle, difficultyLevel } = req.body;
    
    // Validate required fields
    if (!userId || !storyId) {
      res.status(400).json({ error: 'userId and storyId are required' });
      return;
    }
    
    // Get story details if not provided
    let story = { title: storyTitle, difficultyLevel };
    if (!storyTitle || !difficultyLevel) {
      const storyDoc = await db.collection(STORIES_COLLECTION).doc(storyId).get();
      if (storyDoc.exists) {
        const storyData = storyDoc.data();
        story.title = storyData.title;
        story.difficultyLevel = storyData.difficultyLevel;
      }
    }
    
    const completionData = {
      type: 'story',
      userId,
      userName: userName || 'Unknown User',
      userEmail: userEmail || null,
      storyId,
      storyTitle: story.title || 'Unknown Story',
      difficultyLevel: story.difficultyLevel || 0,
      completedAt: new Date(),
      notificationSent: false
    };
    
    // Save to Firestore
    const docRef = await db.collection(USER_COMPLETIONS_COLLECTION).add(completionData);
    
    // Check if we're in debug/development mode (skip emails in dev)
    const isDebugMode = process.env.DEBUG_MODE === 'true' || 
                        process.env.FUNCTIONS_EMULATOR === 'true' ||
                        (process.env.GCLOUD_PROJECT && process.env.GCLOUD_PROJECT.includes('dev'));
    
    if (isDebugMode) {
      console.log('🔧 Debug mode detected - skipping email notification');
      res.status(201).json({
        success: true,
        message: 'Story completion tracked (debug mode - email skipped)',
        completionId: docRef.id,
        emailSent: false,
        debug: true
      });
      return;
    }
    
    // Send email notification (only in production)
    const emailHtml = `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
          .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
          .badge { display: inline-block; background: #4CAF50; color: white; padding: 8px 16px; border-radius: 20px; font-weight: bold; margin: 10px 0; }
          .info-box { background: white; padding: 20px; margin: 15px 0; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
          .info-row { padding: 10px 0; border-bottom: 1px solid #eee; }
          .info-row:last-child { border-bottom: none; }
          .label { font-weight: bold; color: #667eea; display: inline-block; width: 150px; }
          .emoji { font-size: 24px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1><span class="emoji">🎉</span> Story Completed!</h1>
          </div>
          <div class="content">
            <div class="badge">Story Completion</div>
            <div class="info-box">
              <div class="info-row">
                <span class="label">📚 Story:</span> ${story.title}
              </div>
              <div class="info-row">
                <span class="label">⭐ Level:</span> ${story.difficultyLevel}
              </div>
              <div class="info-row">
                <span class="label">👤 User:</span> ${userName || 'Unknown User'}
              </div>
              ${userEmail ? `<div class="info-row"><span class="label">📧 Email:</span> ${userEmail}</div>` : ''}
              <div class="info-row">
                <span class="label">🆔 User ID:</span> ${userId}
              </div>
              <div class="info-row">
                <span class="label">⏰ Completed:</span> ${new Date(completionData.completedAt).toLocaleString()}
              </div>
            </div>
            <p style="color: #666; font-size: 14px; margin-top: 20px;">
              This is an automated notification from Arabic Stories app.
            </p>
          </div>
        </div>
      </body>
      </html>
    `;
    
    const emailSent = await sendEmail(
      `📚 Story Completed: ${story.title} (Level ${story.difficultyLevel})`,
      emailHtml
    );
    
    // Update notification status
    if (emailSent) {
      await docRef.update({ notificationSent: true });
    }
    
    res.status(201).json({
      success: true,
      message: 'Story completion tracked',
      completionId: docRef.id,
      emailSent
    });
  } catch (error) {
    console.error('Error tracking story completion:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Track level completion
 * POST /api/completions/level
 * Body: { userId, userName, userEmail, level, completedAt }
 */
app.post('/api/completions/level', async (req, res) => {
  try {
    const { userId, userName, userEmail, level } = req.body;
    
    // Validate required fields
    if (!userId || !level) {
      res.status(400).json({ error: 'userId and level are required' });
      return;
    }
    
    const completionData = {
      type: 'level',
      userId,
      userName: userName || 'Unknown User',
      userEmail: userEmail || null,
      level: parseInt(level),
      completedAt: new Date(),
      notificationSent: false
    };
    
    // Save to Firestore
    const docRef = await db.collection(USER_COMPLETIONS_COLLECTION).add(completionData);
    
    // Check if we're in debug/development mode (skip emails in dev)
    const isDebugMode = process.env.DEBUG_MODE === 'true' || 
                        process.env.FUNCTIONS_EMULATOR === 'true' ||
                        (process.env.GCLOUD_PROJECT && process.env.GCLOUD_PROJECT.includes('dev'));
    
    if (isDebugMode) {
      console.log('🔧 Debug mode detected - skipping email notification for level completion');
      res.status(201).json({
        success: true,
        message: 'Level completion tracked (debug mode - email skipped)',
        completionId: docRef.id,
        emailSent: false,
        debug: true
      });
      return;
    }
    
    // Send email notification (only in production)
    const emailHtml = `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
          .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
          .badge { display: inline-block; background: #FF6B6B; color: white; padding: 8px 16px; border-radius: 20px; font-weight: bold; margin: 10px 0; }
          .level-badge { display: inline-block; background: #4ECDC4; color: white; padding: 15px 30px; border-radius: 50%; font-size: 32px; font-weight: bold; margin: 20px 0; }
          .info-box { background: white; padding: 20px; margin: 15px 0; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
          .info-row { padding: 10px 0; border-bottom: 1px solid #eee; }
          .info-row:last-child { border-bottom: none; }
          .label { font-weight: bold; color: #f5576c; display: inline-block; width: 150px; }
          .emoji { font-size: 24px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1><span class="emoji">🏆</span> Level Completed!</h1>
          </div>
          <div class="content">
            <div style="text-align: center;">
              <div class="level-badge">${level}</div>
              <div class="badge">Level Achievement</div>
            </div>
            <div class="info-box">
              <div class="info-row">
                <span class="label">👤 User:</span> ${userName || 'Unknown User'}
              </div>
              ${userEmail ? `<div class="info-row"><span class="label">📧 Email:</span> ${userEmail}</div>` : ''}
              <div class="info-row">
                <span class="label">🆔 User ID:</span> ${userId}
              </div>
              <div class="info-row">
                <span class="label">⏰ Completed:</span> ${new Date(completionData.completedAt).toLocaleString()}
              </div>
            </div>
            <p style="color: #666; font-size: 14px; margin-top: 20px;">
              This is an automated notification from Arabic Stories app.
            </p>
          </div>
        </div>
      </body>
      </html>
    `;
    
    const emailSent = await sendEmail(
      `🏆 Level ${level} Completed by ${userName || 'User'}`,
      emailHtml
    );
    
    // Update notification status
    if (emailSent) {
      await docRef.update({ notificationSent: true });
    }
    
    res.status(201).json({
      success: true,
      message: 'Level completion tracked',
      completionId: docRef.id,
      emailSent
    });
  } catch (error) {
    console.error('Error tracking level completion:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Get user completions
 * GET /api/completions?userId=xxx&type=story|level
 */
app.get('/api/completions', async (req, res) => {
  try {
    const { userId, type, limit = 50 } = req.query;
    
    let query = db.collection(USER_COMPLETIONS_COLLECTION)
      .orderBy('completedAt', 'desc')
      .limit(parseInt(limit));
    
    if (userId) {
      query = query.where('userId', '==', userId);
    }
    
    if (type) {
      query = query.where('type', '==', type);
    }
    
    const snapshot = await query.get();
    const completions = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    res.json({
      success: true,
      count: completions.length,
      completions
    });
  } catch (error) {
    console.error('Error getting completions:', error);
    res.status(500).json({ error: error.message });
  }
});

// Global error handler to ensure all errors return JSON
app.use((err, req, res, next) => {
  console.error('========================================');
  console.error('GLOBAL ERROR HANDLER CAUGHT:', err);
  console.error('Request URL:', req.url);
  console.error('Request Method:', req.method);
  console.error('Error stack:', err.stack);
  console.error('========================================');
  
  // Always return JSON error, never HTML
  res.status(500).json({
    success: false,
    error: err.message || 'Internal server error',
    details: 'Global error handler caught this error',
    timestamp: new Date().toISOString(),
    url: req.url,
    method: req.method
  });
});

// 404 handler - also return JSON
app.use('*', (req, res) => {
  console.log('404 - Route not found:', req.method, req.originalUrl);
  res.status(404).json({
    success: false,
    error: 'Route not found',
    method: req.method,
    url: req.originalUrl,
    availableRoutes: [
      'GET /',
      'GET /api/stories', 
      'POST /api/quran-words/:id/audio',
      'GET /api/quran-words/:id/audio/test'
    ]
  });
});

// Export the Express app as a Firebase Function
exports.api = functions.https.onRequest(app);
