class ArabicStoriesApp {
    constructor() {
        this.currentStory = null;
        this.currentChapter = null;
        this.showHarakat = true;
        this.stories = [];
        this.loadStoriesIndex();
    }

    async loadStoriesIndex() {
        try {
            const response = await fetch('./data/stories/index.json');
            if (!response.ok) {
                throw new Error(`Failed to load stories index: ${response.status}`);
            }
            const data = await response.json();
            this.stories = data.stories;
            this.initializeApp();
        } catch (error) {
            console.error('Error loading stories:', error);
            this.showErrorMessage('Failed to load stories. Please refresh the page.');
        }
    }

    async loadStoryMetadata(storyId) {
        try {
            const response = await fetch(`./data/stories/${storyId}/story.json`);
            if (!response.ok) {
                throw new Error(`Failed to load story metadata: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Error loading story metadata:', error);
            return null;
        }
    }

    async loadChapter(storyId, chapterFile) {
        try {
            const response = await fetch(`./data/stories/${storyId}/${chapterFile}`);
            if (!response.ok) {
                throw new Error(`Failed to load chapter: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Error loading chapter:', error);
            return null;
        }
    }

    showErrorMessage(message) {
        const errorDiv = document.createElement('div');
        errorDiv.style.cssText = 'background-color: #f8d7da; color: #721c24; padding: 15px; margin: 10px; border-radius: 4px; text-align: center; font-size: 16px;';
        errorDiv.textContent = message;
        document.body.insertBefore(errorDiv, document.body.firstChild);
    }

    initializeApp() {
        this.bindEvents();
        this.populateStoriesList();
    }

    bindEvents() {
        document.getElementById('back-btn').addEventListener('click', () => {
            this.goHome();
        });

        document.getElementById('back-to-story').addEventListener('click', () => {
            this.backToStory();
        });

        document.getElementById('show-translation').addEventListener('click', () => {
            this.showFullTranslation();
        });

        document.getElementById('hide-translation').addEventListener('click', () => {
            this.hideFullTranslation();
        });

        document.getElementById('toggle-harakat').addEventListener('click', () => {
            this.toggleHarakat();
        });

        document.addEventListener('click', (e) => {
            if (!e.target.classList.contains('arabic-word')) {
                this.hideWordTranslation();
            }
        });
    }

    populateStoriesList() {
        const storiesList = document.getElementById('stories-list');

        storiesList.innerHTML = '';

        this.stories.forEach(story => {
            const storyCard = document.createElement('div');
            storyCard.className = 'story-card';
            storyCard.innerHTML = `
                <h3>${story.title}</h3>
                <p class="story-preview">${story.chapterCount} chapters available</p>
            `;
            storyCard.addEventListener('click', () => {
                this.openStory(story);
            });
            storiesList.appendChild(storyCard);
        });
    }

    async openStory(story) {
        this.showLoading(true);
        
        const storyMetadata = await this.loadStoryMetadata(story.folder);
        if (!storyMetadata) {
            this.showErrorMessage('Failed to load story. Please try again.');
            this.showLoading(false);
            return;
        }
        
        this.currentStory = { ...story, ...storyMetadata };
        document.getElementById('story-title').textContent = this.currentStory.title;

        this.populateChaptersList();
        this.showScreen('story');
        this.showLoading(false);
    }

    populateChaptersList() {
        const chaptersList = document.getElementById('chapters-list');
        chaptersList.innerHTML = '';

        const sortedChapters = [...this.currentStory.chapters].sort((a, b) => a.order - b.order);

        sortedChapters.forEach(chapter => {
            const chapterCard = document.createElement('div');
            chapterCard.className = 'story-card';
            chapterCard.innerHTML = `
                <h3>Chapter ${chapter.order}</h3>
                <p class="story-preview">Click to load chapter...</p>
            `;
            chapterCard.addEventListener('click', () => {
                this.openChapter(chapter);
            });
            chaptersList.appendChild(chapterCard);
        });
    }

    async openChapter(chapter) {
        this.showLoading(true);
        
        const chapterData = await this.loadChapter(this.currentStory.id, chapter.file);
        if (!chapterData) {
            this.showErrorMessage('Failed to load chapter. Please try again.');
            this.showLoading(false);
            return;
        }
        
        this.currentChapter = chapterData;
        document.getElementById('chapter-title').textContent = chapterData.title;

        this.updateArabicText();

        document.getElementById('english-translation').textContent = chapterData.englishTranslation;
        document.getElementById('urdu-translation').textContent = chapterData.urduTranslation;

        this.showScreen('chapter');
        this.showLoading(false);
    }
    
    showLoading(show) {
        const loadingEl = document.getElementById('loading');
        if (show) {
            loadingEl.classList.remove('hidden');
        } else {
            loadingEl.classList.add('hidden');
        }
    }

    updateArabicText() {
        if (!this.currentChapter) return;

        const arabicTextContainer = document.getElementById('arabic-text');
        const textToShow = this.showHarakat ? this.currentChapter.arabicText : (this.currentChapter.arabicTextNoHarakat || this.currentChapter.arabicText);
        arabicTextContainer.innerHTML = this.createClickableText(textToShow, this.currentChapter.wordDictionary);
    }

    backToStory() {
        this.showScreen('story');
        this.hideFullTranslation();
        this.hideWordTranslation();
    }

    toggleHarakat() {
        this.showHarakat = !this.showHarakat;
        this.updateArabicText();

        const toggleBtn = document.getElementById('toggle-harakat');
        toggleBtn.textContent = this.showHarakat ? 'Hide Arabic Diacritics' : 'Show Arabic Diacritics';
    }

    createClickableText(text, translations) {
        const words = text.split(' ');
        return words.map(word => {
            const cleanWord = word.replace(/[،.؟!]/g, '');
            const punctuation = word.replace(cleanWord, '');

            if (translations[cleanWord]) {
                return `<span class="arabic-word" data-word="${cleanWord}" data-translation="${translations[cleanWord]}">${cleanWord}</span>${punctuation}`;
            } else {
                return `<span class="arabic-word-no-translation">${word}</span>`;
            }
        }).join(' ');
    }

    showWordTranslation(event) {
        const wordElement = event.target;
        const word = wordElement.dataset.word;
        const translation = wordElement.dataset.translation;

        if (translation) {
            document.getElementById('selected-word').textContent = word;
            document.getElementById('word-meaning').textContent = translation;
            document.getElementById('word-translation').classList.remove('hidden');
        }
    }

    hideWordTranslation() {
        document.getElementById('word-translation').classList.add('hidden');
    }

    showFullTranslation() {
        document.getElementById('full-translation').classList.remove('hidden');
        document.getElementById('show-translation').classList.add('hidden');
        document.getElementById('hide-translation').classList.remove('hidden');
    }

    hideFullTranslation() {
        document.getElementById('full-translation').classList.add('hidden');
        document.getElementById('hide-translation').classList.add('hidden');
        document.getElementById('show-translation').classList.remove('hidden');
    }

    showScreen(screenId) {
        document.querySelectorAll('.screen').forEach(screen => {
            screen.classList.remove('active');
        });
        document.getElementById(screenId).classList.add('active');
    }

    goHome() {
        this.showScreen('home');
        this.hideFullTranslation();
        this.hideWordTranslation();
    }
}

document.addEventListener('DOMContentLoaded', () => {
    const app = new ArabicStoriesApp();

    document.addEventListener('click', (e) => {
        if (e.target.classList.contains('arabic-word')) {
            app.showWordTranslation(e);
        }
    });
});
