# Arabicly - Arabic Learning Through Stories

A beautiful iOS app for learning Arabic through interactive stories with Firebase cloud storage.

## Features

- **Story Library**: Browse stories with grid layout, filters, and search
- **Bilingual Reader**: Arabic (RTL) + English with tap-to-see-meaning
- **Audio Narration**: Word-by-word highlighting synchronized with audio
- **SRS Flashcards**: Spaced repetition system for vocabulary learning
- **Progress Tracking**: Streaks, achievements, and learning statistics
- **Cloud Sync**: All data stored in Firebase Firestore

## Architecture

### Data Storage
- **Primary**: Firebase Firestore (cloud database)
- **Cache**: Local in-memory + UserDefaults for offline access
- **Models**: Swift structs (Codable for JSON/Firebase)

### Key Components

| Component | Description |
|-----------|-------------|
| `FirebaseService` | Direct Firestore operations |
| `DataService` | Business logic with caching |
| `LocalCache` | In-memory + UserDefaults cache |

## Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)

2. Add an iOS app with bundle ID: `com.yourcompany.hikaya`

3. Download `GoogleService-Info.plist` and replace the placeholder in:
   ```
   ArabicStories/Resources/GoogleService-Info.plist
   ```

4. Enable Firestore Database and create collections:
   - `stories` - Store story content
   - `users/{userId}` - Store user progress

5. Add Firebase SDK via Swift Package Manager:
   ```
   https://github.com/firebase/firebase-ios-sdk
     ```
   Select: `FirebaseFirestore`, `FirebaseStorage`, `FirebaseAuth` (optional)

## Data Structure

### Story Collection
```
stories/{storyId}
  - id: String
  - title: String
  - titleArabic: String
  - storyDescription: String
  - difficultyLevel: Int (1-5)
  - category: String
  - segments: [Segment]
  - words: [Word]
  - createdAt: Timestamp
```

### User Progress
```
users/{userId}
  - currentStreak: Int
  - totalWordsLearned: Int
  - storiesCompleted: Int
  - weeklyStudyMinutes: [Int]
```

## Sample Data Import

Upload the included `sample_stories.json` to Firestore or use the JSON Import feature in the app.

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Firebase account

## Build Instructions

1. Open `ArabicStories.xcodeproj`
2. Add your `GoogleService-Info.plist`
3. Build and run (Cmd+R)

## License

MIT License
