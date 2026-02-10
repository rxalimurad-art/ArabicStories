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
  
  return {
    id: storyData.id || require('crypto').randomUUID(),
    title: storyData.title || '',
    titleArabic: storyData.titleArabic || null,
    storyDescription: storyData.storyDescription || '',
    storyDescriptionArabic: storyData.storyDescriptionArabic || null,
    author: storyData.author || 'Anonymous',
    difficultyLevel: Math.min(Math.max(parseInt(storyData.difficultyLevel) || 1, 1), 5),
    category: storyData.category || 'general',
    tags: Array.isArray(storyData.tags) ? storyData.tags : [],
    coverImageURL: storyData.coverImageURL || null,
    audioNarrationURL: storyData.audioNarrationURL || null,
    segments: (storyData.segments || []).map((seg, idx) => ({
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
    })),
    words: (storyData.words || []).map(word => ({
      id: word.id || require('crypto').randomUUID(),
      arabic: word.arabic || '',
      english: word.english || '',
      transliteration: word.transliteration || null,
      partOfSpeech: word.partOfSpeech || null,
      rootLetters: word.rootLetters || null,
      exampleSentence: word.exampleSentence || null,
      difficulty: word.difficulty || 1
    })),
    grammarNotes: (storyData.grammarNotes || []).map(note => ({
      id: note.id || require('crypto').randomUUID(),
      title: note.title || '',
      explanation: note.explanation || '',
      exampleArabic: note.exampleArabic || '',
      exampleEnglish: note.exampleEnglish || '',
      ruleCategory: note.ruleCategory || 'general',
      createdAt: now
    })),
    isUserCreated: false,
    isDownloaded: false,
    downloadDate: null,
    sourceURL: storyData.sourceURL || null,
    readingProgress: 0,
    currentSegmentIndex: 0,
    completedWords: {},
    isBookmarked: false,
    totalReadingTime: 0,
    viewCount: 0,
    completionCount: 0,
    averageRating: null,
    createdAt: storyData.createdAt || now,
    updatedAt: now
  };
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
    
    const snapshot = await db.collection(STORIES_COLLECTION)
      .orderBy('createdAt', 'desc')
      .limit(limit)
      .offset(offset)
      .get();
    
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
        difficultyLevel: s.difficultyLevel,
        category: s.category,
        segmentCount: s.segments?.length || 0,
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
    
    if (!storyData.title || !storyData.storyDescription) {
      res.status(400).json({ 
        error: 'Missing required fields: title and storyDescription are required' 
      });
      return;
    }

    const formattedStory = formatStoryForFirestore(storyData);
    await db.collection(STORIES_COLLECTION).doc(formattedStory.id).set(formattedStory);
    
    await logAdminAction('CREATE_STORY', { storyId: formattedStory.id, title: formattedStory.title }, req.ip);
    
    res.status(201).json({
      success: true,
      message: 'Story created successfully',
      story: {
        id: formattedStory.id,
        title: formattedStory.title,
        segmentCount: formattedStory.segments.length,
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
    await logAdminAction('UPDATE_STORY', { storyId, title: formattedStory.title }, req.ip);
    
    res.json({
      success: true,
      message: 'Story updated successfully',
      story: { id: storyId, title: formattedStory.title }
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

    const difficulty = parseInt(storyData.difficultyLevel);
    if (isNaN(difficulty) || difficulty < 1 || difficulty > 5) {
      errors.push('Difficulty level must be between 1 and 5');
    }

    res.json({
      success: errors.length === 0,
      valid: errors.length === 0,
      errors,
      warnings,
      summary: {
        title: storyData.title,
        segmentCount: storyData.segments?.length || 0,
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
        difficultyLevel: 1,
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
      results.push({ id: formatted.id, title: formatted.title });
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

// Export the Express app as a Firebase Function
exports.api = functions.https.onRequest(app);
