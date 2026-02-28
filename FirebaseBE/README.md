# Arabic Stories - Firebase + PWA

A complete solution with:
- 🔥 **Firebase Functions API** - Story completion tracking with email notifications
- 📱 **React PWA** - Mobile-first web app that feels native

## Project Structure

```
FirebaseBE/
├── functions/          # Firebase Functions API
│   ├── index.js       # /api/completions/story endpoint only
│   └── package.json
├── pwa/               # React PWA
│   ├── src/           # React components & pages
│   ├── index.html
│   ├── vite.config.js # PWA configuration
│   └── package.json
├── firebase.json      # Combined deployment config
└── firestore.rules
```

## Quick Start

### 1. Install Dependencies

```bash
# API dependencies
cd functions
npm install

# PWA dependencies
cd ../pwa
npm install
```

### 2. Configure Firebase

Update `.firebaserc`:
```json
{
  "projects": {
    "default": "YOUR_PROJECT_ID"
  }
}
```

### 3. Run Locally

```bash
# Terminal 1 - PWA dev server
cd pwa
npm run dev

# Terminal 2 - Firebase emulators
cd ..
firebase emulators:start
```

- PWA: http://localhost:5173
- API: http://localhost:5001/YOUR_PROJECT/us-central1/api
- Firebase Console: http://localhost:4000

### 4. Deploy

```bash
# Deploy everything (API + PWA)
firebase deploy

# Or deploy separately
firebase deploy --only functions
firebase deploy --only hosting
```

## API Endpoint

### POST `/api/completions/story`

Track story completion and send email notification.

```json
{
  "userId": "user123",
  "userName": "John Doe",
  "userEmail": "john@example.com",
  "storyId": "story456",
  "storyTitle": "The Friendly Cat",
  "difficultyLevel": 1
}
```

## PWA Features

- 📱 **Native App Feel** - Bottom navigation, smooth transitions
- 📴 **Offline Support** - Works without internet
- ⬇️ **Installable** - Add to home screen
- 🔔 **Push Ready** - Service worker configured
- 🎨 **Mobile-Optimized** - Safe areas, touch feedback

## Routes

- `/` - Home (dashboard)
- `/stories` - Story list
- `/stories/:id` - Story reader
- `/profile` - User profile

## Customization

### Change Theme

Edit `pwa/tailwind.config.js`:
```javascript
colors: {
  primary: {
    500: '#your-color',
    600: '#your-color-dark',
  }
}
```

### Add Firebase Integration

Edit `pwa/src/pages/Home.jsx` and replace mock data:
```javascript
import { collection, getDocs } from 'firebase/firestore'
import { db } from '../firebase'

// Fetch real stories
const snapshot = await getDocs(collection(db, 'stories'))
```

## Icons

Open `pwa/public/icon-generator.html` in browser and click "Generate All Icons" to download PWA icons.

## Environment Variables (Optional)

For production email configuration:
```bash
firebase functions:config:set gmail.user="your-email@gmail.com" gmail.pass="app-password"
```

Then update `functions/index.js` to use `functions.config()` instead of hardcoded values.

## License

MIT
