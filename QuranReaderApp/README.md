# Quran Reader App - قرآن کریم ایپ

A comprehensive React Native application for reading the Holy Quran with Arabic text, Urdu translation, and detailed commentary.

## Features - خصوصیات

### Core Features
- **📖 Complete Quran** - All 114 Surahs with Arabic text
- **🌍 Urdu Translation** - Complete Urdu translation with proper formatting
- **📚 Multiple Commentary** - Both traditional and modern commentary (Ghamidi & classical)
- **🔍 Search Functionality** - Search in both Arabic text and Urdu translation
- **🔖 Bookmarks** - Save and manage favorite verses
- **⚙️ Customizable Settings** - Font sizes, themes, display preferences

### User Interface
- **🎨 Beautiful Design** - Clean, readable interface optimized for Arabic text
- **🌙 RTL Support** - Proper right-to-left text rendering
- **📱 Responsive** - Works on all device sizes
- **🎯 Easy Navigation** - Quick access to any Surah or verse
- **💾 Offline Ready** - All data stored locally for offline reading

## JSON Data Structure

The app uses a comprehensive JSON structure containing:

```typescript
interface SurahParagraph {
  paragraph: string;           // Paragraph number within surah
  ayat: number[];             // Array of ayah numbers in this paragraph
  arabic: string;             // Arabic text
  tadtraur: string;           // Clean Urdu translation
  albtraur: string;           // HTML-formatted Urdu with references
  albcomur: Commentary[];     // Ghamidi commentary
  tadcomur: string[];         // Traditional tafseer
  // ... additional metadata
}
```

### Data Paths
- **Main Quran Data**: `src/data/json/surah-{1-114}.json`
- **Surah Metadata**: `src/data/surahs.ts`
- **Types**: `src/types/index.ts`

## Installation - تنصیب

### Prerequisites
- Node.js (v16 or higher)
- React Native development environment
- Android Studio (for Android) or Xcode (for iOS)

### Setup Steps

1. **Copy Quran Data**
   ```bash
   cd QuranReaderApp
   ./copy_quran_data.sh
   ```
   This script copies all 114 Quran JSON files from your existing project.

2. **Install Dependencies**
   ```bash
   npm install
   ```

3. **iOS Setup** (macOS only)
   ```bash
   cd ios && pod install && cd ..
   ```

4. **Run the Application**
   ```bash
   # For iOS
   npx react-native run-ios
   
   # For Android
   npx react-native run-android
   
   # Start Metro bundler (if not started automatically)
   npm start
   ```

## Project Structure

```
QuranReaderApp/
├── src/
│   ├── data/
│   │   ├── json/              # Quran JSON files (surah-1.json to surah-114.json)
│   │   └── surahs.ts          # Surah metadata
│   ├── screens/
│   │   ├── HomeScreen.tsx     # Main dashboard
│   │   ├── SurahListScreen.tsx    # Browse all surahs
│   │   ├── SurahReaderScreen.tsx  # Read Quran with translation
│   │   ├── CommentaryScreen.tsx   # View detailed commentary
│   │   ├── SearchScreen.tsx       # Search functionality
│   │   ├── BookmarksScreen.tsx    # Manage bookmarks
│   │   └── SettingsScreen.tsx     # App preferences
│   ├── types/
│   │   └── index.ts           # TypeScript type definitions
│   ├── utils/
│   │   └── DataManager.ts     # JSON data loading and management
│   └── components/            # Reusable UI components
├── App.tsx                    # Main app navigation
├── package.json               # Dependencies and scripts
└── README.md                  # This file
```

## Features Detail

### 1. Surah Reading
- **Arabic Text**: Beautiful rendering with proper Arabic fonts
- **Urdu Translation**: Clear, readable Urdu translation
- **Verse Numbers**: Easy verse identification and navigation
- **Bismillah**: Automatically displayed for relevant surahs

### 2. Commentary System
- **Ghamidi Commentary**: Modern scholarly commentary
- **Traditional Tafseer**: Classical Islamic commentary
- **HTML Formatting**: Rich text with proper styling
- **Reference Links**: Cross-references and citations

### 3. Search Engine
- **Dual Language Search**: Search in both Arabic and Urdu
- **Fast Results**: Efficient text matching
- **Context Preview**: See surrounding verses
- **Direct Navigation**: Jump to any result

### 4. Bookmark Management
- **Quick Save**: Long-press to bookmark verses
- **Notes Support**: Add personal notes to bookmarks
- **Easy Organization**: Sort by date or surah
- **Backup Ready**: Stored in AsyncStorage

### 5. Customization
- **Font Sizes**: Separate controls for Arabic and translation
- **Theme Options**: Light and dark modes
- **Display Toggle**: Show/hide translation and commentary
- **Language Settings**: UI language preferences

## Technical Details

### Dependencies
- **React Navigation**: Screen navigation and routing
- **AsyncStorage**: Local data persistence
- **React Native Render HTML**: Rich text rendering
- **TypeScript**: Type safety and better development experience

### Performance
- **Lazy Loading**: Surahs loaded on demand
- **Memory Management**: Efficient caching system
- **Optimized Rendering**: Smooth scrolling for long surahs
- **Offline First**: No internet required after installation

### Data Format
The app uses the same JSON structure from your existing quran_react project:
- Each surah is a separate JSON file
- Paragraphs contain multiple ayahs grouped thematically
- Rich metadata including revelation type, verse counts
- Multiple commentary sources with unique identifiers

## Customization

### Adding More Commentary
To add additional commentary sources:
1. Extend the `Commentary` interface in `src/types/index.ts`
2. Update `SurahParagraph` to include new commentary fields
3. Modify `CommentaryScreen.tsx` to display new sources

### Theming
Themes are defined in individual screen stylesheets. To add a new theme:
1. Update `AppSettings` interface in types
2. Create theme color schemes in a separate utility file
3. Apply conditional styling throughout the app

### Language Support
To add more languages:
1. Add language option to `AppSettings`
2. Create translation files for UI text
3. Update all screen components with multilingual support

## Troubleshooting

### Common Issues

1. **JSON Files Not Found**
   - Run `./copy_quran_data.sh` to copy data files
   - Ensure source directory path is correct in the script

2. **Build Errors**
   - Run `npm install` to ensure all dependencies are installed
   - For iOS: `cd ios && pod install`
   - Clear Metro cache: `npx react-native start --reset-cache`

3. **Performance Issues**
   - Reduce font sizes in settings
   - Close other apps to free memory
   - Restart the app if experiencing lag

### Development Tips

1. **Hot Reload**: Use Metro bundler for fast development cycles
2. **Debugging**: Use React Native Debugger or Flipper
3. **Testing**: Test on both iOS and Android devices
4. **Performance**: Use React DevTools to profile component renders

## Contributing

This app is designed to be easily extensible:

1. **Add New Features**: Follow the established patterns in screens/
2. **Improve Commentary**: Enhance the commentary parsing and display
3. **UI Enhancements**: Improve the visual design and user experience
4. **Performance**: Optimize data loading and rendering

## License

This project is designed for educational and religious purposes. Please ensure compliance with copyright laws when using Quran text and commentary data.

---

**بِسْمِ اللّٰہِ الرَّحْمٰنِ الرَّحِیْمِ**

*Built with ❤️ for the Muslim community*