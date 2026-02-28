# Hifz - Arabic Memorizer

A complete Firebase solution:
- 🔥 **Firebase Functions API** - Story completion tracking (optional)
- 📱 **React PWA** - Personal Arabic verse memorizer with Firestore

## Project Structure

```
FirebaseBE/
├── functions/          # API (optional - completions endpoint)
├── hifz-pwa/          # Main memorizer app (Firestore-based)
│   ├── src/
│   │   ├── pages/
│   │   │   ├── Home.jsx
│   │   │   ├── Groups.jsx
│   │   │   ├── Memorize.jsx    # Card slider with TTS
│   │   │   └── Admin.jsx       # Add groups/lines
│   │   ├── hooks/
│   │   │   ├── useStore.js     # Firestore operations
│   │   │   └── useSpeech.js    # TTS
│   │   └── firebase.js         # Firebase config
│   └── dist/           # Built app
└── firebase.json       # Deployment config
```

## Quick Start - Hifz PWA

### 1. Get Firebase Config

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create/select project
3. Project settings → Your apps → Web → Register app
4. Copy the config

### 2. Update Config

Edit `hifz-pwa/src/firebase.js` with your actual config.

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

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /hifz_groups/{group} {
      allow read, write: if true;  // For personal use
    }
  }
}
```

## Features

| Feature | Description |
|---------|-------------|
| **Groups** | Organize by Surah/Chapter |
| **Lines** | Individual verses |
| **TTS** | Text-to-speech (tap 🔊) |
| **Translation** | Tap card to reveal |
| **Progress** | Not started / Learning / Memorized |
| **Offline** | Works without internet |
| **Cloud Sync** | Data in Firestore |

## Data Flow

```
[Your Phone] ←→ [Firestore] ←→ [Other Devices]
     ↓              ↓
 [Offline] ←→ [Cache]
```

## Usage

1. **Admin** (⚙️) → Add Group → "Al-Fatiha"
2. **Admin** → Add Lines (Arabic + optional translation)
3. **Home** → See progress dashboard
4. **Groups** → Tap group to start
5. **Memorize** → Listen with TTS, mark status

## PWA Install

- **iOS Safari**: Share → Add to Home Screen
- **Android Chrome**: Menu → Add to Home Screen

## API (Optional)

The Functions API at `/api/completions/story` can track completions separately.
