const fs = require('fs');
const path = require('path');

// Import the missing translations dictionary
const missingTranslations = require('./missing_translations_dictionary.js');

async function updateAllChaptersWithTranslations() {
    const storiesPath = './data/stories';
    const indexPath = path.join(storiesPath, 'index.json');
    
    // Read the stories index
    const indexData = JSON.parse(fs.readFileSync(indexPath, 'utf8'));
    
    console.log('🔄 Starting translation updates...\n');
    
    // Update each story
    for (const story of indexData.stories) {
        const storyPath = path.join(storiesPath, story.folder);
        const storyMetaPath = path.join(storyPath, 'story.json');
        
        if (!fs.existsSync(storyMetaPath)) {
            console.log(`❌ Story metadata not found: ${story.folder}`);
            continue;
        }
        
        const storyData = JSON.parse(fs.readFileSync(storyMetaPath, 'utf8'));
        
        console.log(`📖 Updating story: ${story.title}`);
        
        // Update each chapter
        for (const chapter of storyData.chapters) {
            const chapterPath = path.join(storyPath, chapter.file);
            
            if (!fs.existsSync(chapterPath)) {
                console.log(`   ❌ Chapter file not found: ${chapter.file}`);
                continue;
            }
            
            const chapterData = JSON.parse(fs.readFileSync(chapterPath, 'utf8'));
            let updatedCount = 0;
            
            // Update word dictionary with missing translations
            if (!chapterData.wordDictionary) {
                chapterData.wordDictionary = {};
            }
            
            // Add missing translations
            for (const [arabicWord, translation] of Object.entries(missingTranslations)) {
                if (!chapterData.wordDictionary[arabicWord]) {
                    chapterData.wordDictionary[arabicWord] = translation;
                    updatedCount++;
                }
            }
            
            if (updatedCount > 0) {
                // Save the updated chapter file
                fs.writeFileSync(chapterPath, JSON.stringify(chapterData, null, 2), 'utf8');
                console.log(`   ✅ Chapter ${chapter.order}: Added ${updatedCount} translations`);
            } else {
                console.log(`   ℹ️  Chapter ${chapter.order}: No new translations needed`);
            }
        }
    }
    
    console.log('\n🎉 Translation updates completed!');
    console.log('\nRunning verification analysis...\n');
    
    // Run verification analysis
    const { execSync } = require('child_process');
    try {
        execSync('node analyze_translations.js', { stdio: 'inherit' });
    } catch (error) {
        console.log('Note: Run analyze_translations.js separately to verify the updates');
    }
}

// Run the update
updateAllChaptersWithTranslations().catch(console.error);