// Script to import Sarf data into Firestore
// Run this with: node import-sarf.js

import { initializeApp } from 'firebase/app'
import { getFirestore, collection, addDoc, serverTimestamp } from 'firebase/firestore'
import fs from 'fs'

// Your Firebase config (from firebase.js)
const firebaseConfig = {
  // Replace with your actual config or import from firebase.js
  apiKey: "YOUR_API_KEY",
  authDomain: "YOUR_PROJECT.firebaseapp.com",
  projectId: "YOUR_PROJECT",
  storageBucket: "YOUR_PROJECT.appspot.com",
  messagingSenderId: "YOUR_SENDER_ID",
  appId: "YOUR_APP_ID"
}

// Read the sarf data
const sarfData = JSON.parse(fs.readFileSync('./sarf-data.json', 'utf8'))

async function importSarf() {
  const app = initializeApp(firebaseConfig)
  const db = getFirestore(app)
  
  console.log('🚀 Importing Sarf data into Firestore...\n')
  
  for (const group of sarfData.groups) {
    try {
      const docRef = await addDoc(collection(db, 'hifz_groups'), {
        name: group.name,
        tags: group.tags,
        lines: group.lines.map((line, idx) => ({
          id: Date.now().toString() + idx,
          arabic: line.arabic,
          translation: line.translation,
          status: 'not_started',
          createdAt: new Date().toISOString()
        })),
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp()
      })
      console.log(`✅ Created: ${group.name} (${group.lines.length} lines)`)
    } catch (err) {
      console.error(`❌ Error creating ${group.name}:`, err.message)
    }
  }
  
  console.log('\n🎉 Done! Open your PWA to start learning.')
  process.exit(0)
}

// Alternative: If you want to use the local emulator or existing Firebase instance
// You can also copy-paste this data into the Admin page of your PWA

console.log('📚 Sarf Import Script')
console.log('=====================')
console.log('\nOption 1: Run this script with your Firebase config')
console.log('Option 2: Copy data from sarf-data.json and add manually via PWA Admin\n')

// Uncomment to run:
// importSarf()
