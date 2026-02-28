import { initializeApp } from 'firebase/app'
import { getFirestore, enableIndexedDbPersistence } from 'firebase/firestore'

const firebaseConfig = {
  apiKey: "AIzaSyADxkMGSOdqALGGFRbOttRwPM-oovCriN8",
  authDomain: "arabicstories-82611.firebaseapp.com",
  projectId: "arabicstories-82611",
  storageBucket: "arabicstories-82611.firebasestorage.app",
  messagingSenderId: "304828677382",
  appId: "1:304828677382:web:9803f76cbb936d08e37287",
  measurementId: "G-5HG1B04C50"
}

const app = initializeApp(firebaseConfig)
export const db = getFirestore(app)

// Enable offline persistence
enableIndexedDbPersistence(db)
  .catch((err) => {
    if (err.code === 'failed-precondition') {
      console.log('Multiple tabs open, persistence enabled in first tab only')
    } else if (err.code === 'unimplemented') {
      console.log('Browser does not support offline persistence')
    }
  })

export default app
