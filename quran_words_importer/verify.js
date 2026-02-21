/**
 * Verification script for Quran Words import
 * Checks the imported data in Firestore
 */

const admin = require('firebase-admin');
const path = require('path');

const CONFIG = {
  PROJECT_ID: 'arabicstories-82611',
  STORAGE_BUCKET: 'arabicstories-82611.firebasestorage.app',
  COLLECTION_NAME: 'quran_words',
};

function initializeFirebase() {
  const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');
  
  if (require('fs').existsSync(serviceAccountPath)) {
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

async function verifyImport() {
  console.log('========================================');
  console.log('Quran Words Import Verification');
  console.log('========================================\n');
  
  const db = initializeFirebase();
  
  // Get total count
  const snapshot = await db.collection(CONFIG.COLLECTION_NAME).get();
  console.log(`Total documents in collection: ${snapshot.size}\n`);
  
  // Check documents with audio
  const withAudio = await db.collection(CONFIG.COLLECTION_NAME)
    .where('audioURL', '!=', '')
    .get();
  console.log(`Documents with audio: ${withAudio.size}`);
  
  // Check documents without audio
  const withoutAudio = await db.collection(CONFIG.COLLECTION_NAME)
    .where('audioURL', '==', '')
    .get();
  console.log(`Documents without audio: ${withoutAudio.size}\n`);
  
  // Sample documents
  console.log('Sample documents:');
  console.log('----------------------------------------');
  
  const sample = await db.collection(CONFIG.COLLECTION_NAME)
    .orderBy('rank', 'asc')
    .limit(5)
    .get();
  
  sample.forEach(doc => {
    const data = doc.data();
    console.log(`Rank ${data.rank}: ${data.arabicText}`);
    console.log(`  Meaning: ${data.englishMeaning}`);
    console.log(`  Audio: ${data.audioURL ? '✓' : '✗'}`);
    console.log(`  Tags: ${data.tags?.join(', ')}`);
    console.log(`  Example: ${data.exampleArabic} - ${data.exampleEnglish}`);
    console.log('');
  });
  
  // Check ranks 1-10
  console.log('Top 10 words verification:');
  console.log('----------------------------------------');
  
  for (let i = 1; i <= 10; i++) {
    const query = await db.collection(CONFIG.COLLECTION_NAME)
      .where('rank', '==', i)
      .get();
    
    if (query.empty) {
      console.log(`Rank ${i}: MISSING`);
    } else {
      const data = query.docs[0].data();
      console.log(`Rank ${i}: ${data.arabicText} ✓`);
    }
  }
  
  console.log('\n========================================');
  console.log('Verification Complete');
  console.log('========================================');
  
  process.exit(0);
}

verifyImport().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});
