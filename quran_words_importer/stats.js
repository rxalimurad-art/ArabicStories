/**
 * Stats Script - Check Quran Words Collection Stats
 * Shows how many words are in the database without importing
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

const CONFIG = {
  PROJECT_ID: 'arabicstories-82611',
  STORAGE_BUCKET: 'arabicstories-82611.firebasestorage.app',
  COLLECTION_NAME: 'quran_words',
};

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

async function showStats() {
  console.log('========================================');
  console.log('Quran Words Collection Stats');
  console.log('========================================\n');
  
  const db = initializeFirebase();
  
  try {
    // Total count
    const snapshot = await db.collection(CONFIG.COLLECTION_NAME).get();
    const totalCount = snapshot.size;
    
    console.log(`Total words in collection: ${totalCount}`);
    
    if (totalCount === 0) {
      console.log('\nCollection is empty. No words imported yet.');
      console.log('Run "npm start" to import words.\n');
      process.exit(0);
    }
    
    // Words with audio
    const withAudioSnapshot = await db.collection(CONFIG.COLLECTION_NAME)
      .where('audioURL', '!=', '')
      .get();
    const withAudioCount = withAudioSnapshot.size;
    
    // Words without audio  
    const withoutAudioSnapshot = await db.collection(CONFIG.COLLECTION_NAME)
      .where('audioURL', '==', '')
      .get();
    const withoutAudioCount = withoutAudioSnapshot.size;
    
    // Rank stats
    const lowestRankDoc = await db.collection(CONFIG.COLLECTION_NAME)
      .orderBy('rank', 'desc')
      .limit(1)
      .get();
    
    const highestRankDoc = await db.collection(CONFIG.COLLECTION_NAME)
      .orderBy('rank', 'asc')
      .limit(1)
      .get();
    
    // Part of speech counts
    const posCounts = {};
    snapshot.forEach(doc => {
      const pos = doc.data().morphology?.partOfSpeech || 'Unknown';
      posCounts[pos] = (posCounts[pos] || 0) + 1;
    });
    
    console.log(`\nAudio Status:`);
    console.log(`  With audio: ${withAudioCount}`);
    console.log(`  Without audio: ${withoutAudioCount}`);
    
    if (!highestRankDoc.empty) {
      const highest = highestRankDoc.docs[0].data();
      console.log(`\nRank Range:`);
      console.log(`  Best (lowest) rank: ${highest.rank} - ${highest.arabicText}`);
    }
    
    if (!lowestRankDoc.empty) {
      const lowest = lowestRankDoc.docs[0].data();
      console.log(`  Highest rank in collection: ${lowest.rank} - ${lowest.arabicText}`);
    }
    
    console.log(`\nPart of Speech Distribution:`);
    Object.entries(posCounts)
      .sort((a, b) => b[1] - a[1])
      .forEach(([pos, count]) => {
        const percentage = ((count / totalCount) * 100).toFixed(1);
        console.log(`  ${pos}: ${count} (${percentage}%)`);
      });
    
    // Show top 10 words by rank
    console.log(`\nTop 10 Words by Rank:`);
    console.log('----------------------------------------');
    const topWords = await db.collection(CONFIG.COLLECTION_NAME)
      .orderBy('rank', 'asc')
      .limit(10)
      .get();
    
    topWords.forEach(doc => {
      const data = doc.data();
      const audioStatus = data.audioURL ? '✓' : '✗';
      console.log(`  ${data.rank}. ${data.arabicText} - ${data.englishMeaning} [${audioStatus}]`);
    });
    
    // Show recent imports (last 5)
    console.log(`\nRecently Added Words:`);
    console.log('----------------------------------------');
    const recentWords = await db.collection(CONFIG.COLLECTION_NAME)
      .orderBy('createdAt', 'desc')
      .limit(5)
      .get();
    
    if (recentWords.empty) {
      console.log('  No timestamp data available');
    } else {
      recentWords.forEach(doc => {
        const data = doc.data();
        const date = data.createdAt ? data.createdAt.toDate().toLocaleString() : 'Unknown';
        console.log(`  ${data.arabicText} (rank ${data.rank}) - ${date}`);
      });
    }
    
    console.log('\n========================================');
    console.log('Stats Complete');
    console.log('========================================');
    
  } catch (error) {
    console.error(`Error fetching stats: ${error.message}`);
    process.exit(1);
  }
  
  process.exit(0);
}

showStats().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});
