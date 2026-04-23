const fs = require('fs');
const path = require('path');

async function findMissingTranslations() {
    const storiesPath = './data/stories';
    const indexPath = path.join(storiesPath, 'index.json');
    
    // Read the stories index
    const indexData = JSON.parse(fs.readFileSync(indexPath, 'utf8'));
    
    const missingWords = new Set();
    const allWords = new Set();
    const translatedWords = new Set();
    
    // Analyze each story
    for (const story of indexData.stories) {
        const storyPath = path.join(storiesPath, story.folder);
        const storyMetaPath = path.join(storyPath, 'story.json');
        
        const storyData = JSON.parse(fs.readFileSync(storyMetaPath, 'utf8'));
        
        console.log(`\n📖 Analyzing story: ${story.title}`);
        
        // Analyze each chapter
        for (const chapter of storyData.chapters) {
            const chapterPath = path.join(storyPath, chapter.file);
            
            if (!fs.existsSync(chapterPath)) {
                console.log(`❌ Chapter file not found: ${chapter.file}`);
                continue;
            }
            
            const chapterData = JSON.parse(fs.readFileSync(chapterPath, 'utf8'));
            
            // Extract words from Arabic text
            const arabicText = chapterData.arabicText || '';
            const words = arabicText
                .split(/[\s\n]+/)
                .map(word => word.replace(/[،.؟!]/g, ''))
                .filter(word => word.length > 0);
            
            const wordDictionary = chapterData.wordDictionary || {};
            
            console.log(`   Chapter ${chapter.order}: ${chapterData.title}`);
            
            let chapterMissingCount = 0;
            const chapterMissing = [];
            
            // Check each word
            for (const word of words) {
                allWords.add(word);
                
                if (wordDictionary[word]) {
                    translatedWords.add(word);
                } else {
                    missingWords.add(word);
                    chapterMissing.push(word);
                    chapterMissingCount++;
                }
            }
            
            if (chapterMissingCount > 0) {
                console.log(`   ❗ Missing ${chapterMissingCount} translations in this chapter:`);
                console.log(`   ${chapterMissing.slice(0, 10).join(', ')}${chapterMissing.length > 10 ? '...' : ''}`);
            } else {
                console.log(`   ✅ All words have translations`);
            }
        }
    }
    
    // Generate summary report
    console.log(`\n\n📊 TRANSLATION ANALYSIS SUMMARY`);
    console.log(`===============================`);
    console.log(`Total unique words found: ${allWords.size}`);
    console.log(`Words with translations: ${translatedWords.size}`);
    console.log(`Words missing translations: ${missingWords.size}`);
    console.log(`Translation coverage: ${((translatedWords.size / allWords.size) * 100).toFixed(2)}%`);
    
    if (missingWords.size > 0) {
        console.log(`\n❌ MISSING TRANSLATIONS (${missingWords.size} words):`);
        console.log(`=====================================`);
        const sortedMissing = Array.from(missingWords).sort();
        sortedMissing.forEach((word, index) => {
            console.log(`${(index + 1).toString().padStart(3)}. ${word}`);
        });
        
        // Save missing words to file
        const missingWordsReport = {
            summary: {
                totalWords: allWords.size,
                translatedWords: translatedWords.size,
                missingWords: missingWords.size,
                coverage: ((translatedWords.size / allWords.size) * 100).toFixed(2) + '%'
            },
            missingWordsList: sortedMissing
        };
        
        fs.writeFileSync('./missing_translations_report.json', JSON.stringify(missingWordsReport, null, 2));
        console.log(`\n📄 Detailed report saved to: missing_translations_report.json`);
    } else {
        console.log(`\n✅ Great! All words have translations.`);
    }
}

// Run the analysis
findMissingTranslations().catch(console.error);