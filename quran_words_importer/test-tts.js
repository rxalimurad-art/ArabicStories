/**
 * Test TTS functionality
 * Run this before the full import to verify audio generation works
 */

const { generateTTS, saveAudioToFile } = require('./tts');
const fs = require('fs');
const path = require('path');

async function testTTS() {
  console.log('========================================');
  console.log('TTS Test Script');
  console.log('========================================\n');
  
  // Test words
  const testWords = [
    'فِى',
    'ٱللَّهِ',
    'مِن',
    'كِتَٰبٌ',
    'صَلَاةٌ',
  ];
  
  // Create audio directory
  const audioDir = path.join(__dirname, 'audio');
  if (!fs.existsSync(audioDir)) {
    fs.mkdirSync(audioDir, { recursive: true });
  }
  
  for (const word of testWords) {
    console.log(`\nTesting: "${word}"`);
    console.log('-'.repeat(40));
    
    const audioBuffer = await generateTTS(word);
    
    if (audioBuffer) {
      const filename = `test_${Buffer.from(word).toString('base64').substring(0, 8)}.mp3`;
      const savedPath = saveAudioToFile(audioBuffer, filename);
      console.log(`✓ Success! Saved to: ${savedPath}`);
      console.log(`  Size: ${audioBuffer.length} bytes`);
    } else {
      console.log('✗ Failed to generate audio');
    }
    
    // Wait a bit between requests to avoid rate limiting
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  
  console.log('\n========================================');
  console.log('TTS Test Complete');
  console.log('========================================');
  console.log(`\nCheck the 'audio' folder for generated files.`);
  console.log('If files are generated and playable, TTS is working correctly.');
  
  process.exit(0);
}

testTTS().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});
