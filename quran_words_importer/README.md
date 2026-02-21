# Quran Words Importer

Node.js project to import top 200 Quran words from a JSON file into Firestore with TTS audio generation.

## Features

- Reads top 200 words from `quran_words_2026-02-17.json`
- Generates Arabic TTS audio using Google Translate TTS
- Uploads audio files to Firebase Storage
- Enriches data with examples, root meanings, and grammar notes
- Saves to Firestore `quran_words` collection in `nam5` location

## Prerequisites

1. Node.js 18+ installed
2. Firebase project access with appropriate permissions
3. Service account key OR gcloud CLI authenticated

## Setup

### 1. Install Dependencies

```bash
cd quran_words_importer
npm install
```

### 2. Firebase Authentication

#### Option A: Service Account Key (Recommended)

1. Go to Firebase Console → Project Settings → Service Accounts
2. Click "Generate new private key"
3. Save the JSON file as `serviceAccountKey.json` in this directory

#### Option B: Application Default Credentials

```bash
gcloud auth application-default login
```

### 3. Verify Firebase Project

Ensure the project ID in `index.js` matches your Firebase project:

```javascript
const CONFIG = {
  PROJECT_ID: 'arabicstories-82611',
  STORAGE_BUCKET: 'arabicstories-82611.firebasestorage.app',
  // ...
};
```

## Usage

### Check Current Stats (Before Importing)

See how many words are already in the database:

```bash
npm run stats
```

This shows:
- Total words in collection
- Words with/without audio
- Rank range of existing words
- Part of speech distribution
- Top 10 words by rank
- Recently added words

### Run the Importer

```bash
npm start
```

The importer will:
1. Show current stats (words already in Firebase)
2. Show how many new words will be imported
3. Show which words already exist (will be skipped)
4. Import only the new words with audio generation
5. Show updated total count

### Dry Run (Test without saving)

To test without saving to Firestore, modify the script:

```javascript
// Add this before the import
const DRY_RUN = true;

// And wrap the Firestore save:
if (!DRY_RUN) {
  await db.collection(CONFIG.COLLECTION_NAME).doc(wordId).set(doc);
}
```

## Data Format

Each word document in Firestore has the following structure:

```javascript
{
  id: "uuid",
  arabicText: "فِى",
  arabicWithoutDiacritics: "فى",
  buckwalter: "fiY",
  englishMeaning: "In",
  audioURL: "https://storage.googleapis.com/.../word-audio/uuid.mp3",
  exampleArabic: "فِى ٱلْبَيْتِ",
  exampleEnglish: "In the house",
  morphology: {
    breakdown: "فِى[P]",
    form: null,
    gender: null,
    grammaticalCase: null,
    lemma: "فِي",
    number: null,
    partOfSpeech: "P",
    passive: false,
    posDescription: "حرف جر",
    state: null,
    tense: null,
  },
  root: {
    arabic: "N/A",
    transliteration: "N/A",
    meaning: "N/A",
  },
  occurrenceCount: 1098,
  rank: 1,
  tags: ["preposition", "particle", "most-frequent"],
  notes: "Most frequent word in the Quran...",
  createdAt: Timestamp,
  updatedAt: Timestamp,
}
```

## Troubleshooting

### TTS Not Working

If Google Translate TTS fails, the script will continue without audio. You can:

1. Use a different TTS service by modifying `generateTTS()` function
2. Add audio manually later

### Firebase Permission Denied

Make sure your service account has these roles:
- Cloud Datastore User (for Firestore)
- Storage Object Admin (for Storage)

### Rate Limiting

The script includes a 500ms delay between words. If you hit rate limits:

1. Increase the delay in the script
2. Run in smaller batches

## File Structure

```
quran_words_importer/
├── index.js              # Main import script
├── stats.js             # Check database stats
├── tts.js               # TTS module
├── verify.js            # Verify imported data
├── test-tts.js          # Test TTS functionality
├── package.json         # Dependencies
├── README.md            # This file
├── .env.example         # Environment template
├── serviceAccountKey.json # (Optional) Firebase credentials
└── .gitignore           # Git ignore file
```

## Customization

### Modify Number of Words

Change `TOP_N_WORDS` in the config:

```javascript
const CONFIG = {
  TOP_N_WORDS: 200, // Change to desired number
  // ...
};
```

### Add More Examples

Edit the `QURAN_EXAMPLES` object in `index.js` to add specific examples for words.

### Add Root Meanings

Edit the `ROOT_MEANINGS` object in `index.js` to add meanings for Arabic roots.

## License

MIT
