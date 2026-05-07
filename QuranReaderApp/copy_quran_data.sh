#!/bin/bash

# Script to copy all Quran JSON files from the existing project
# Run this script to populate the React Native app with all Quran data

SOURCE_DIR="/Users/amurad/Desktop/ArabicStories/quran_react/scraper/output"
DEST_DIR="/Users/amurad/Desktop/ArabicStories/QuranReaderApp/src/data/json"

echo "Copying Quran JSON files..."
echo "Source: $SOURCE_DIR"
echo "Destination: $DEST_DIR"

# Create destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Copy all surah JSON files
for i in {1..114}; do
    source_file="$SOURCE_DIR/surah-$i.json"
    dest_file="$DEST_DIR/surah-$i.json"
    
    if [ -f "$source_file" ]; then
        cp "$source_file" "$dest_file"
        echo "Copied surah-$i.json"
    else
        echo "Warning: surah-$i.json not found in source directory"
    fi
done

echo ""
echo "Copy completed!"
echo "Total files copied: $(ls -1 $DEST_DIR/*.json 2>/dev/null | wc -l)"
echo ""
echo "To use this app:"
echo "1. cd QuranReaderApp"
echo "2. npm install"
echo "3. For iOS: npx react-native run-ios"
echo "4. For Android: npx react-native run-android"