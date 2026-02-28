const functions = require('firebase-functions');
const express = require('express');
const cors = require('cors');
const nodemailer = require('nodemailer');

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// Email config
const emailTransporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'volutiontechnologies@gmail.com',
    pass: 'tneh ndls rjjq pffm'
  }
});

// Story completion endpoint
app.post('/completions/story', async (req, res) => {
  try {
    const { userId, userName, userEmail, storyId, storyTitle, difficultyLevel } = req.body;
    
    if (!userId || !storyId) {
      return res.status(400).json({ error: 'userId and storyId are required' });
    }
    
    const story = {
      title: storyTitle || 'Unknown Story',
      difficultyLevel: difficultyLevel || 0
    };
    
    // Send email notification
    const emailHtml = `
      <h2>🎉 Story Completed!</h2>
      <p><strong>Story:</strong> ${story.title}</p>
      <p><strong>Level:</strong> ${story.difficultyLevel}</p>
      <p><strong>User:</strong> ${userName || 'Unknown'}</p>
      <p><strong>User ID:</strong> ${userId}</p>
    `;
    
    let emailSent = false;
    try {
      await emailTransporter.sendMail({
        from: '"Arabic Stories" <volutiontechnologies@gmail.com>',
        to: 'volutiontechnologies@gmail.com',
        subject: `📚 Story Completed: ${story.title}`,
        html: emailHtml
      });
      emailSent = true;
    } catch (e) {
      console.log('Email failed:', e.message);
    }
    
    res.status(201).json({
      success: true,
      message: 'Story completion tracked',
      data: {
        userId,
        storyId,
        storyTitle: story.title,
        difficultyLevel: story.difficultyLevel,
        completedAt: new Date()
      },
      emailSent
    });
    
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Health check
app.get('/', (req, res) => {
  res.json({ status: 'ok', service: 'Arabic Stories API' });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Not found', path: req.originalUrl });
});

exports.api = functions.https.onRequest(app);
