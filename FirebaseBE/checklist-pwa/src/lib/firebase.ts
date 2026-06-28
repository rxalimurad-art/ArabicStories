import { initializeApp } from 'firebase/app';
import {
  initializeFirestore,
  persistentLocalCache,
  persistentMultipleTabManager,
} from 'firebase/firestore';

// Web SDK config for the shared "DailyChecklist" Firebase app.
// (apiKey is a public client identifier, not a secret — access is governed by
// Firestore security rules.)
const firebaseConfig = {
  apiKey: 'AIzaSyADxkMGSOdqALGGFRbOttRwPM-oovCriN8',
  authDomain: 'arabicstories-82611.firebaseapp.com',
  projectId: 'arabicstories-82611',
  storageBucket: 'arabicstories-82611.firebasestorage.app',
  messagingSenderId: '304828677382',
  appId: '1:304828677382:web:f30505c28c088b6ee37287',
};

const app = initializeApp(firebaseConfig);

// IndexedDB-backed offline cache → the app stays fast and works offline,
// syncing to Firestore automatically when back online.
export const db = initializeFirestore(app, {
  localCache: persistentLocalCache({ tabManager: persistentMultipleTabManager() }),
});
