const functions = require('firebase-functions');
const express = require('express');
const cors = require('cors');
const { TextToSpeechClient } = require('@google-cloud/text-to-speech');

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// Initialize TTS client (uses service account from environment)
const ttsClient = new TextToSpeechClient();

// Health check
app.get('/', (req, res) => {
  res.json({ status: 'ok', service: 'Hifz TTS API' });
});

// Text-to-Speech endpoint with Chirp voices
app.post('/tts', async (req, res) => {
  try {
    const { text, voiceType = 'chirp-female' } = req.body;
    
    if (!text || text.trim() === '') {
      return res.status(400).json({ error: 'Text is required' });
    }
    
    // Voice configuration - FIXED mapping
    let voiceConfig = {
      languageCode: 'ar-XA',
      name: 'ar-XA-Chirp3-HD-A', // Female voice
    };
    
    // Alternative voice options with correct voice names
    if (voiceType === 'chirp-male') {
      voiceConfig = {
        languageCode: 'ar-XA',
        name: 'ar-XA-Chirp3-HD-D', // Male voice
      };
    } else if (voiceType === 'wavenet-female') {
      voiceConfig = {
        languageCode: 'ar-XA',
        name: 'ar-XA-Wavenet-A', // Female
      };
    } else if (voiceType === 'wavenet-male') {
      voiceConfig = {
        languageCode: 'ar-XA',
        name: 'ar-XA-Wavenet-B', // Male
      };
    } else if (voiceType === 'chirp-female') {
      // Use ar-XA-Chirp3-HD-A (Female)
      voiceConfig = {
        languageCode: 'ar-XA',
        name: 'ar-XA-Chirp3-HD-A',
      };
    }
    
    // Log which voice is being used
    console.log('Using voice:', voiceConfig.name, 'for type:', voiceType);
    
    const request = {
      input: { text },
      voice: voiceConfig,
      audioConfig: {
        audioEncoding: 'MP3',
        speakingRate: 0.85, // Slightly slower for memorization
        pitch: 0,
        effectsProfileId: ['headphone-class-device'] // Optimized for headphones/mobile
      }
    };
    
    const [response] = await ttsClient.synthesizeSpeech(request);
    
    // Return base64 audio
    const audioContent = response.audioContent.toString('base64');
    
    res.json({
      success: true,
      audioContent,
      encoding: 'MP3',
      voice: voiceConfig.name
    });
    
  } catch (error) {
    console.error('TTS Error:', error);
    res.status(500).json({ 
      error: 'TTS failed', 
      details: error.message 
    });
  }
});

exports.api = functions.https.onRequest(app);
