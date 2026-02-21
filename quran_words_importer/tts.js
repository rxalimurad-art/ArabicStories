/**
 * TTS (Text-to-Speech) Module
 * Multiple TTS providers for Arabic audio generation
 */

const axios = require('axios');
const https = require('https');

/**
 * Generate TTS using Google Translate TTS API
 * This is a free API but has rate limits
 */
async function googleTranslateTTS(text) {
  try {
    const encodedText = encodeURIComponent(text);
    const url = `https://translate.google.com/translate_tts?ie=UTF-8&q=${encodedText}&tl=ar&client=tw-ob`;
    
    const response = await axios.get(url, {
      responseType: 'arraybuffer',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Referer': 'https://translate.google.com/',
      },
      timeout: 30000,
      httpsAgent: new https.Agent({
        rejectUnauthorized: false,
      }),
    });
    
    return Buffer.from(response.data);
  } catch (error) {
    console.error(`Google TTS failed: ${error.message}`);
    return null;
  }
}

/**
 * Generate TTS using ResponsiveVoice API (requires API key for production)
 */
async function responsiveVoiceTTS(text, apiKey = null) {
  if (!apiKey) {
    console.log('ResponsiveVoice: No API key provided, skipping');
    return null;
  }
  
  try {
    const url = 'https://api.responsivevoice.org/v1/text:synthesize';
    const response = await axios.post(url, {
      text: text,
      lang: 'ar',
      engine: 'g1',
      key: apiKey,
    }, {
      responseType: 'arraybuffer',
      timeout: 30000,
    });
    
    return Buffer.from(response.data);
  } catch (error) {
    console.error(`ResponsiveVoice TTS failed: ${error.message}`);
    return null;
  }
}

/**
 * Generate TTS using VoiceRSS API (requires API key)
 */
async function voiceRSSTTS(text, apiKey = null) {
  if (!apiKey) {
    console.log('VoiceRSS: No API key provided, skipping');
    return null;
  }
  
  try {
    const encodedText = encodeURIComponent(text);
    const url = `https://api.voicerss.org/?key=${apiKey}&hl=ar-sa&src=${encodedText}&f=44khz_16bit_stereo`;
    
    const response = await axios.get(url, {
      responseType: 'arraybuffer',
      timeout: 30000,
    });
    
    // VoiceRSS returns error as text if failed
    if (response.data.toString().startsWith('ERROR')) {
      console.error(`VoiceRSS error: ${response.data.toString()}`);
      return null;
    }
    
    return Buffer.from(response.data);
  } catch (error) {
    console.error(`VoiceRSS TTS failed: ${error.message}`);
    return null;
  }
}

/**
 * Generate TTS using IBM Watson (requires credentials)
 */
async function ibmWatsonTTS(text, apiKey = null, url = null) {
  if (!apiKey || !url) {
    console.log('IBM Watson: No credentials provided, skipping');
    return null;
  }
  
  try {
    const response = await axios.post(
      `${url}/v1/synthesize`,
      {
        text: text,
        voice: 'ar-MS_OmarVoice',
        accept: 'audio/mp3',
      },
      {
        auth: {
          username: 'apikey',
          password: apiKey,
        },
        responseType: 'arraybuffer',
        timeout: 30000,
      }
    );
    
    return Buffer.from(response.data);
  } catch (error) {
    console.error(`IBM Watson TTS failed: ${error.message}`);
    return null;
  }
}

/**
 * Generate TTS using Amazon Polly (requires AWS credentials)
 */
async function amazonPollyTTS(text, credentials = null) {
  if (!credentials) {
    console.log('Amazon Polly: No credentials provided, skipping');
    return null;
  }
  
  try {
    // Would require AWS SDK
    console.log('Amazon Polly: AWS SDK integration not implemented');
    return null;
  } catch (error) {
    console.error(`Amazon Polly TTS failed: ${error.message}`);
    return null;
  }
}

/**
 * Main TTS function - tries multiple providers
 * Priority: Google Translate (free) -> Others (if keys provided)
 */
async function generateTTS(text, config = {}) {
  console.log(`Generating TTS for: "${text}"`);
  
  // Try Google Translate first (free)
  let audioBuffer = await googleTranslateTTS(text);
  if (audioBuffer) {
    console.log('  ✓ Generated using Google Translate TTS');
    return audioBuffer;
  }
  
  // Try ResponsiveVoice if key provided
  if (config.responsiveVoiceKey) {
    audioBuffer = await responsiveVoiceTTS(text, config.responsiveVoiceKey);
    if (audioBuffer) {
      console.log('  ✓ Generated using ResponsiveVoice');
      return audioBuffer;
    }
  }
  
  // Try VoiceRSS if key provided
  if (config.voiceRSSKey) {
    audioBuffer = await voiceRSSTTS(text, config.voiceRSSKey);
    if (audioBuffer) {
      console.log('  ✓ Generated using VoiceRSS');
      return audioBuffer;
    }
  }
  
  // Try IBM Watson if credentials provided
  if (config.ibmWatsonKey && config.ibmWatsonUrl) {
    audioBuffer = await ibmWatsonTTS(text, config.ibmWatsonKey, config.ibmWatsonUrl);
    if (audioBuffer) {
      console.log('  ✓ Generated using IBM Watson');
      return audioBuffer;
    }
  }
  
  console.log('  ✗ All TTS providers failed');
  return null;
}

/**
 * Save audio buffer to file (for testing)
 */
function saveAudioToFile(audioBuffer, filename) {
  const fs = require('fs');
  const path = require('path');
  
  const outputPath = path.join(__dirname, 'audio', filename);
  
  // Create audio directory if not exists
  const audioDir = path.dirname(outputPath);
  if (!fs.existsSync(audioDir)) {
    fs.mkdirSync(audioDir, { recursive: true });
  }
  
  fs.writeFileSync(outputPath, audioBuffer);
  console.log(`Saved audio to: ${outputPath}`);
  
  return outputPath;
}

module.exports = {
  generateTTS,
  googleTranslateTTS,
  responsiveVoiceTTS,
  voiceRSSTTS,
  ibmWatsonTTS,
  amazonPollyTTS,
  saveAudioToFile,
};
