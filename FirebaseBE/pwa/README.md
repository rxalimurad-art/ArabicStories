# Arabic Stories PWA

A mobile-first Progressive Web App for learning Arabic through stories.

## Features

- 📱 **Native App Feel** - Works like a native app on mobile
- 🔧 **PWA** - Installable, works offline, push notifications ready
- 📖 **Story Reader** - Read Arabic stories with translations
- 📊 **Progress Tracking** - Track your learning progress
- ⚡ **Fast** - Optimized for mobile with lazy loading

## Tech Stack

- React 18 + Vite
- Tailwind CSS
- React Router
- Vite PWA Plugin
- Firebase Hosting

## Getting Started

### 1. Install Dependencies

```bash
cd pwa
npm install
```

### 2. Run Development Server

```bash
npm run dev
```

Open http://localhost:5173

### 3. Build for Production

```bash
npm run build
```

### 4. Deploy to Firebase

```bash
# Update .firebaserc with your project ID
# Then deploy
npm run deploy
```

Or manually:
```bash
npm run build
firebase deploy --only hosting
```

## Mobile Testing

### On Your Phone:

1. Make sure your computer and phone are on the same WiFi
2. Find your computer's IP: `ifconfig | grep inet`
3. Open `http://YOUR_IP:5173` on your phone

### In WebView:

The app is optimized for webview with:
- Safe area support (notch/home indicator)
- Touch feedback
- Prevent zoom/pinch
- Smooth scrolling
- Bottom navigation (thumb-friendly)

## PWA Features

### Install on Home Screen:

**iOS Safari:**
1. Tap Share button
2. Tap "Add to Home Screen"

**Android Chrome:**
1. Tap menu (3 dots)
2. Tap "Add to Home screen"

### Offline Support:

The app caches:
- Static assets (JS, CSS, HTML)
- Firebase Storage images
- API responses (5 min cache)

## Project Structure

```
pwa/
├── public/              # Static assets
│   └── icons/          # PWA icons (72x72 to 512x512)
├── src/
│   ├── components/     # Reusable components
│   │   ├── Layout.jsx  # App shell with nav
│   │   ├── StoryCard.jsx
│   │   └── OfflineBanner.jsx
│   ├── pages/          # Route pages
│   │   ├── Home.jsx
│   │   ├── Stories.jsx
│   │   ├── StoryDetail.jsx
│   │   └── Profile.jsx
│   ├── App.jsx
│   ├── main.jsx
│   └── index.css
├── index.html
├── vite.config.js      # PWA config
├── tailwind.config.js
├── firebase.json       # Firebase hosting config
└── package.json
```

## Customization

### Change Theme Color:

1. Update `vite.config.js` - `theme_color` and `background_color`
2. Update `tailwind.config.js` - `colors.primary`
3. Update `index.html` - `theme-color` meta tag

### Add Firebase:

```bash
npm install firebase
```

Then create `src/firebase.js`:
```javascript
import { initializeApp } from 'firebase/app'
import { getFirestore } from 'firebase/firestore'

const firebaseConfig = {
  // your config
}

const app = initializeApp(firebaseConfig)
export const db = getFirestore(app)
```

## Next Steps

1. Add real Firebase integration
2. Add user authentication
3. Add audio playback for stories
4. Add vocabulary flashcards
5. Add push notifications

## License

MIT
