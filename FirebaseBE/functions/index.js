const functions = require('firebase-functions');
const express = require('express');
const cors = require('cors');
const { TextToSpeechClient } = require('@google-cloud/text-to-speech');

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// Initialize TTS client
let ttsClient;
try {
  ttsClient = new TextToSpeechClient();
  console.log('TTS Client initialized successfully');
} catch (err) {
  console.error('Failed to initialize TTS client:', err.message);
}

// Health check
app.get('/', (req, res) => {
  res.json({ 
    status: 'ok', 
    service: 'Hifz TTS API',
    ttsConfigured: !!ttsClient
  });
});

// List available voices (for debugging)
app.get('/voices', async (req, res) => {
  try {
    if (!ttsClient) {
      return res.status(500).json({ error: 'TTS client not initialized' });
    }
    
    const [result] = await ttsClient.listVoices({ languageCode: 'ar-XA' });
    const voices = result.voices || [];
    
    res.json({
      voices: voices.map(v => ({
        name: v.name,
        gender: v.ssmlGender,
        languageCodes: v.languageCodes
      }))
    });
  } catch (error) {
    console.error('List voices error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Text-to-Speech endpoint
app.post('/tts', async (req, res) => {
  let voiceType, voiceConfig;
  
  try {
    const { text, voiceType: requestedVoice = 'chirp-female' } = req.body;
    voiceType = requestedVoice;
    
    if (!text || text.trim() === '') {
      return res.status(400).json({ error: 'Text is required' });
    }
    
    if (!ttsClient) {
      return res.status(500).json({ error: 'TTS client not initialized' });
    }
    
    // Voice mapping - using correct Google Cloud TTS voice names
    // Note: Chirp voices may not be available in all projects/regions
    const voiceMap = {
      'chirp-female': { name: 'ar-XA-Chirp3-HD-D', gender: 'FEMALE' },
      'chirp-male': { name: 'ar-XA-Chirp3-HD-O', gender: 'MALE' },
      'wavenet-female': { name: 'ar-XA-Wavenet-A', gender: 'FEMALE' },
      'wavenet-male': { name: 'ar-XA-Wavenet-B', gender: 'MALE' },
      'standard-female': { name: 'ar-XA-Standard-A', gender: 'FEMALE' },
      'standard-male': { name: 'ar-XA-Standard-B', gender: 'MALE' }
    };
    
    voiceConfig = voiceMap[voiceType] || voiceMap['chirp-female'];
    
    console.log('TTS Request:', {
      voiceType,
      voiceName: voiceConfig.name,
      textLength: text.length
    });
    
    const request = {
      input: { text },
      voice: {
        languageCode: 'ar-XA',
        name: voiceConfig.name,
        ssmlGender: voiceConfig.gender
      },
      audioConfig: {
        audioEncoding: 'MP3',
        speakingRate: 0.85,
        pitch: 0,
        effectsProfileId: ['headphone-class-device']
      }
    };
    
    const [response] = await ttsClient.synthesizeSpeech(request);
    
    const audioContent = response.audioContent.toString('base64');
    
    console.log('TTS Success:', {
      voiceUsed: voiceConfig.name,
      audioLength: audioContent.length
    });
    
    res.json({
      success: true,
      audioContent,
      encoding: 'MP3',
      voice: voiceConfig.name,
      voiceType: voiceType
    });
    
  } catch (error) {
    console.error('TTS Error:', error);
    res.status(500).json({ 
      error: 'TTS failed', 
      details: error.message,
      code: error.code,
      voiceType: voiceType,
      voiceName: voiceConfig?.name,
      hint: 'Chirp voices require allowlist. Try WaveNet or Standard voices.'
    });
  }
});

exports.api = functions.https.onRequest(app);
