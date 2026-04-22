# قصص الأنبياء - Arabic Stories PWA

An interactive Progressive Web App for learning Arabic through stories of the prophets with word-by-word translation.

## Features

- 📖 **Chapter-based Stories** - Complete story of Prophet Ibrahim (AS) with 8 chapters
- 🔤 **Arabic Diacritics** - Toggle between text with and without harakat
- 🎯 **Interactive Translation** - Click any Arabic word for instant translation
- 🌍 **Multi-language Support** - English and Urdu translations
- 📱 **Progressive Web App** - Works offline, installable on mobile devices
- 🎨 **Responsive Design** - Optimized for all screen sizes

## Project Structure

```
qasas-pwa/
├── index.html          # Main HTML file with Arabic layout
├── script.js           # App logic with chapter management
├── styles.css          # Responsive CSS with Arabic fonts
├── manifest.json       # PWA manifest
├── sw.js              # Service worker for offline support
└── package.json       # Project dependencies
```

## Local Development

```bash
# Navigate to the project directory
cd qasas-pwa

# Start local development server
npm run dev
# or
python3 -m http.server 8000

# Open http://localhost:8000
```

## Firebase Deployment

### Prerequisites
- Firebase CLI installed and authenticated
- Access to arabicstories-82611 project

### Deploy Commands

```bash
# Deploy only the Arabic stories PWA
firebase deploy --only hosting:qasas-stories

# Deploy all hosting targets
firebase deploy --only hosting

# Deploy with functions
firebase deploy
```

### Firebase Configuration

The project is configured with:
- **Target**: `qasas-stories`
- **Site**: `qasas-un-nabiyeen`
- **Public Directory**: `qasas-pwa`
- **Offline Support**: Service worker enabled
- **PWA Headers**: Configured for manifest and service worker

## Story Content

### Current Chapters (8 total):
1. **بائع الأصنام** - The Idol Seller
2. **وَلَدُ آزَر** - Azar's Son  
3. **نَصِيحَةُ إِبْرَاهِيمَ** - Ibrahim's Advice
4. **إِبْرَاهِيمُ يَكْسِرُ الْأَصْنَامَ** - Ibrahim Breaks the Idols
5. **مَنْ فَعَلَ هَٰذَا؟** - Who Did This?
6. **نَارٌ بَارِدَةٌ** - Cold Fire
7. **مَنْ رَبِّي** - Who is My Lord  
8. **اللَّهُ رَبِّي** - Allah is My Lord

### Adding New Chapters

To add new chapters, update the `stories` array in `script.js`:

```javascript
{
    id: 9,
    title: "٩ - Chapter Title",
    arabicText: "Arabic text with diacritics...",
    arabicTextNoHarakat: "Arabic text without diacritics...",
    wordTranslations: {
        "word": "translation",
        // ...
    },
    englishTranslation: "English translation...",
    urduTranslation: "Urdu translation..."
}
```

## Technical Features

- **Service Worker**: Offline functionality and caching
- **Responsive Design**: Mobile-first approach
- **Arabic Fonts**: Google Fonts (Amiri) for proper Arabic rendering
- **Right-to-Left Support**: Full RTL layout support
- **Touch Optimized**: Mobile-friendly interactive elements
- **Accessibility**: Screen reader compatible

## Browser Support

- Chrome/Chromium browsers
- Safari (iOS/macOS)
- Firefox
- Edge

## License

MIT License