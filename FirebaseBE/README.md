# Arabic Stories - Firebase Admin

A Firebase Functions-based admin panel for managing Arabic stories in Firestore.

## Features

- 📝 Create, edit, delete stories with bilingual content (English/Arabic)
- 📚 Manage story segments with Arabic text, English translation, and transliteration
- 📖 Vocabulary management with root letters and example sentences
- 🎨 Modern, responsive web interface
- 📤 Import/Export stories as JSON
- ✅ Real-time validation

## Project Structure

```
FirebaseBE/
├── functions/
│   ├── index.js          # Firebase Functions (API endpoints)
│   └── package.json      # Node.js dependencies
├── public/
│   ├── index.html        # Admin UI
│   ├── admin.css         # Styles
│   └── admin.js          # Frontend JavaScript
├── firebase.json         # Firebase configuration
├── firestore.rules       # Security rules
└── README.md
```

## Setup Instructions

### 1. Install Firebase CLI

```bash
npm install -g firebase-tools
```

### 2. Login to Firebase

```bash
firebase login
```

### 3. Initialize Firebase Project

```bash
cd FirebaseBE
firebase init
```

Select:
- Functions
- Hosting
- Firestore
- Emulators (optional, for local development)

### 4. Deploy

```bash
firebase deploy
```

Or deploy specific services:
```bash
firebase deploy --only functions
firebase deploy --only hosting
```

## Local Development

### Using Emulators

```bash
firebase emulators:start
```

This will start:
- Functions emulator on port 5001
- Firestore emulator on port 8080
- Hosting emulator on port 5000
- UI on port 4000

Access the admin panel at: `http://localhost:5000`

### API URL Configuration

If running locally with emulators, click the ⚙️ (settings) button in the header to set the API base URL, e.g.:
```
http://localhost:5001/your-project/us-central1
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/stories` | List all stories |
| GET | `/api/stories/:id` | Get a single story |
| POST | `/api/stories` | Create new story |
| PUT | `/api/stories/:id` | Update story |
| DELETE | `/api/stories/:id` | Delete story |
| POST | `/api/stories/validate` | Validate story data |
| GET | `/api/categories` | Get story categories |
| POST | `/api/seed` | Seed sample stories |

## Story Data Structure

```json
{
  "id": "uuid",
  "title": "Story Title",
  "titleArabic": "عنوان القصة",
  "storyDescription": "Description",
  "storyDescriptionArabic": "الوصف",
  "author": "Author Name",
  "difficultyLevel": 1,
  "category": "children",
  "tags": ["animals", "friendship"],
  "coverImageURL": "https://...",
  "audioNarrationURL": "https://...",
  "segments": [
    {
      "index": 0,
      "arabicText": "النص العربي",
      "englishText": "English text",
      "transliteration": "Transliteration"
    }
  ],
  "words": [
    {
      "arabic": "كلمة",
      "english": "word",
      "transliteration": "kalima",
      "partOfSpeech": "noun"
    }
  ]
}
```

## Firestore Collections

- `stories` - Stores all story content
- `admin_logs` - Admin action logs

## Categories

- general
- folktale
- history
- science
- culture
- adventure
- mystery
- romance
- children
- religious
- poetry
- modern

## Troubleshooting

### CORS Errors
Make sure CORS is properly configured in the functions. The code uses the `cors` middleware.

### Permission Denied
Check your Firestore security rules and ensure they allow the operations you need.

### Functions Not Deploying
Run with debug output:
```bash
firebase deploy --only functions --debug
```

## Security Notes

⚠️ **Important**: This admin panel has no authentication. For production:

1. Add Firebase Authentication
2. Implement proper user roles
3. Use HTTPS only
4. Validate all inputs server-side
5. Implement rate limiting
6. Add audit logging
7. Consider IP whitelisting or VPN access
