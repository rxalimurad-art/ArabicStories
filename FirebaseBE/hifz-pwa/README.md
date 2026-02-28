# Hifz - Personal Arabic Memorizer

A PWA for memorizing Arabic verses with Firebase Firestore storage.

## Features

- 📱 **No accounts needed** - Uses device identifier
- 🔥 **Firebase Firestore** - Cloud storage, syncs across devices
- 🔊 **TTS** - Text-to-speech for Arabic
- 📴 **Works offline** - Firestore caches data locally
- 📊 **Progress tracking** - Not started / Learning / Memorized

## Setup

### 1. Get Firebase Config

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project (or use existing)
3. Click ⚙️ **Project settings** → **Your apps** → **Web**
4. Register app and copy the config object

### 2. Update Config

Edit `src/firebase.js` and replace the config:

```javascript
const firebaseConfig = {
  apiKey: "your-actual-api-key",
  authDomain: "your-project.firebaseapp.com",
  projectId: "your-project-id",
  storageBucket: "your-project.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abcdef"
}
```

### 3. Install & Run

```bash
cd hifz-pwa
npm install
npm run dev
```

### 4. Deploy

```bash
npm run build
firebase deploy --only hosting
```

## Firestore Rules

Add these rules to Firebase Console → Firestore Database → Rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /hifz_groups/{group} {
      allow read, write: if true;
    }
  }
}
```

⚠️ **Note:** These rules allow anyone to read/write. For production, add authentication.

## Data Structure

```
hifz_groups (collection)
  └── {groupId} (document)
        ├── name: "Al-Fatiha"
        ├── lines: [
        │     {
        │       id: "123",
        │       arabic: "بِسْمِ ٱللَّٰهِ...",
        │       translation: "In the name...",
        │       status: "learning"
        │     }
        │   ]
        ├── createdAt: timestamp
        └── updatedAt: timestamp
```

## Usage

1. **Admin** → Add Group (Surah name)
2. **Admin** → Add Lines (verses) with optional translation
3. **Home/Groups** → Tap group to memorize
4. **Memorize** → Listen with TTS, mark progress

## Offline Support

Firestore automatically:
- Caches data locally
- Queues writes when offline
- Syncs when connection returns

Your data is always available even without internet!
