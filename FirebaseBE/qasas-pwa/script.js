class ArabicStoriesApp {
    constructor() {
        this.currentStory = null;
        this.currentChapter = null;
        this.showHarakat = true;
        this.stories = [];
        this.isMobile = window.innerWidth <= 768;
        this.tooltipTimeout = null;
        this.touchStartX = 0;
        this.touchStartY = 0;
        this.minSwipeDistance = 100;
        this.progress = this.loadProgress();
        this.loadStoriesIndex();
        this.setupMobileEnhancements();
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

        document.getElementById('mark-complete-btn').addEventListener('click', () => {
            this.markChapterComplete();
        });



        document.addEventListener('click', (e) => {
            if (!e.target.classList.contains('arabic-word')) {
                this.hideWordTooltip();
            }
        });
    }

    populateStoriesList() {
        const storiesList = document.getElementById('stories-list');

        storiesList.innerHTML = '';

        this.stories.forEach(story => {
            const completedChapters = this.getCompletedChaptersCount(story.id);
            const totalChapters = story.chapterCount;
            const isStoryComplete = completedChapters === totalChapters;
            
            const storyCard = document.createElement('div');
            storyCard.className = `story-card ${isStoryComplete ? 'completed' : ''}`;
            storyCard.innerHTML = `
                <div class="story-header-info">
                    <h3>${story.title}</h3>
                    ${isStoryComplete ? '<div class="complete-badge">✓ Complete</div>' : ''}
                </div>
                <div class="story-progress">
                    <p class="progress-text">${completedChapters}/${totalChapters} chapters read</p>
                    <div class="progress-bar">
                        <div class="progress-fill" style="width: ${(completedChapters / totalChapters) * 100}%"></div>
                    </div>
                </div>
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
        document.getElementById('story-title-nav').textContent = this.currentStory.title;
        this.updateBreadcrumb(['قصص الأنبياء', this.currentStory.title]);

        this.populateChaptersList();
        this.showScreen('story', 'forward');
        this.showSwipeHint(); // Show hint on first story entry
        this.showLoading(false);
    }

    populateChaptersList() {
        const chaptersList = document.getElementById('chapters-list');
        chaptersList.innerHTML = '';

        const sortedChapters = [...this.currentStory.chapters].sort((a, b) => a.order - b.order);

        sortedChapters.forEach(chapter => {
            const isCompleted = this.isChapterCompleted(this.currentStory.id, chapter.order);
            
            const chapterCard = document.createElement('div');
            chapterCard.className = `story-card ${isCompleted ? 'completed' : ''}`;
            chapterCard.innerHTML = `
                <div class="chapter-header">
                    <h3>Chapter ${chapter.order}</h3>
                    ${isCompleted ? '<div class="chapter-complete-icon">✓</div>' : ''}
                </div>
                <p class="story-preview">${isCompleted ? 'Completed' : 'Click to read chapter...'}</p>
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
        document.getElementById('chapter-title-nav').textContent = chapterData.title;
        this.updateBreadcrumb(['قصص الأنبياء', this.currentStory.title, chapterData.title]);

        this.updateArabicText();

        document.getElementById('english-translation').textContent = chapterData.englishTranslation;
        document.getElementById('urdu-translation').textContent = chapterData.urduTranslation;

        this.updateCompleteButton();
        this.showScreen('chapter', 'forward');
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
        arabicTextContainer.innerHTML = this.createClickableText(this.currentChapter.arabicText, this.currentChapter.wordDictionary);
    }

    backToStory() {
        this.showScreen('story', 'backward');
        this.hideWordTooltip();
    }


    createClickableText(text, translations) {
        const sentences = text.split('.');
        return sentences.map(sentence => {
            if (!sentence.trim()) return '';
            
            const words = sentence.trim().split(' ');
            const processedWords = words.map(word => {
                const cleanWord = word.replace(/[،.؟!]/g, '');
                const punctuation = word.replace(cleanWord, '');

                if (translations[cleanWord]) {
                    return `<span class="arabic-word" data-word="${cleanWord}" data-translation="${translations[cleanWord]}">${cleanWord}</span>${punctuation}`;
                } else {
                    return `<span class="arabic-word-no-translation">${word}</span>`;
                }
            });
            
            return processedWords.join(' ') + '.';
        }).filter(sentence => sentence !== '.').join('<br>');
    }

    showWordTooltip(event) {
        const wordElement = event.target;
        const translation = wordElement.dataset.translation;

        if (translation) {
            // Clear any existing timeout
            if (this.tooltipTimeout) {
                clearTimeout(this.tooltipTimeout);
                this.tooltipTimeout = null;
            }

            const tooltip = document.getElementById('word-tooltip');
            const wordMeaning = document.getElementById('word-meaning');
            
            wordMeaning.textContent = translation;
            tooltip.classList.remove('hidden');
            
            // Position tooltip above the clicked word with proper spacing
            const rect = wordElement.getBoundingClientRect();
            const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
            const scrollLeft = window.pageXOffset || document.documentElement.scrollLeft;
            
            // Calculate tooltip height to position it properly above the word
            tooltip.style.visibility = 'hidden';
            tooltip.style.display = 'block';
            const tooltipHeight = tooltip.offsetHeight;
            tooltip.style.visibility = 'visible';
            tooltip.style.display = '';
            
            tooltip.style.left = (rect.left + rect.width / 2 + scrollLeft) + 'px';
            tooltip.style.top = (rect.top - tooltipHeight - 15 + scrollTop) + 'px';

            // Auto-hide tooltip after 2 seconds
            this.tooltipTimeout = setTimeout(() => {
                this.hideWordTooltip();
            }, 2000);
        }
    }

    hideWordTooltip() {
        document.getElementById('word-tooltip').classList.add('hidden');
        
        // Clear any pending timeout
        if (this.tooltipTimeout) {
            clearTimeout(this.tooltipTimeout);
            this.tooltipTimeout = null;
        }
    }


    showScreen(screenId, direction = 'forward') {
        const currentScreen = document.querySelector('.screen.active');
        const nextScreen = document.getElementById(screenId);

        if (currentScreen === nextScreen) return;

        // Prepare next screen
        nextScreen.style.display = 'block';
        
        if (direction === 'forward') {
            // Forward animation (slide left)
            if (currentScreen) {
                currentScreen.classList.add('slide-out');
            }
            nextScreen.style.transform = 'translateX(100%)';
            nextScreen.style.opacity = '0';
            
            // Trigger transition
            requestAnimationFrame(() => {
                nextScreen.style.transform = 'translateX(0)';
                nextScreen.style.opacity = '1';
            });
        } else {
            // Backward animation (slide right)
            if (currentScreen) {
                currentScreen.style.transform = 'translateX(100%)';
                currentScreen.style.opacity = '0';
            }
            nextScreen.style.transform = 'translateX(-100%)';
            nextScreen.style.opacity = '0';
            
            // Trigger transition
            requestAnimationFrame(() => {
                nextScreen.style.transform = 'translateX(0)';
                nextScreen.style.opacity = '1';
            });
        }

        // Clean up after animation
        setTimeout(() => {
            // Hide all screens and remove animation classes
            document.querySelectorAll('.screen').forEach(screen => {
                screen.classList.remove('active', 'slide-out', 'slide-in');
                if (screen !== nextScreen) {
                    screen.style.display = 'none';
                    screen.style.transform = '';
                    screen.style.opacity = '';
                }
            });
            
            // Activate the new screen
            nextScreen.classList.add('active');
            nextScreen.style.transform = '';
            nextScreen.style.opacity = '';
        }, 300);
    }

    goHome() {
        this.showScreen('home', 'backward');
        this.hideWordTooltip();
        this.updateBreadcrumb(['قصص الأنبياء']);
    }

    updateBreadcrumb(items) {
        const breadcrumbEl = document.getElementById('nav-breadcrumb');
        breadcrumbEl.innerHTML = '';
        
        items.forEach((item, index) => {
            const span = document.createElement('span');
            span.className = 'breadcrumb-item';
            span.textContent = item;
            
            if (index === items.length - 1) {
                span.classList.add('active');
            }
            
            breadcrumbEl.appendChild(span);
        });
        
        // Update main title for home screen
        if (items.length === 1) {
            document.getElementById('main-title').style.display = 'block';
            document.getElementById('subtitle').style.display = 'block';
        } else {
            document.getElementById('main-title').style.display = 'none';
            document.getElementById('subtitle').style.display = 'none';
        }
    }

    setupMobileEnhancements() {
        // Add touch feedback for mobile devices
        if (this.isMobile) {
            // Prevent zoom on double tap
            document.addEventListener('touchstart', (e) => {
                if (e.touches.length > 1) {
                    e.preventDefault();
                }
            }, { passive: false });

            // Add haptic feedback for supported devices
            this.addHapticFeedback();
            
            // Improve scroll behavior
            document.body.style.webkitOverflowScrolling = 'touch';
            
            // Add orientation change handling
            window.addEventListener('orientationchange', () => {
                setTimeout(() => {
                    this.handleOrientationChange();
                }, 100);
            });

            // Add swipe navigation
            this.setupSwipeNavigation();
        }

        // Handle window resize
        window.addEventListener('resize', () => {
            this.isMobile = window.innerWidth <= 768;
        });
    }

    setupSwipeNavigation() {
        document.addEventListener('touchstart', (e) => {
            this.touchStartX = e.touches[0].clientX;
            this.touchStartY = e.touches[0].clientY;
        }, { passive: true });

        document.addEventListener('touchend', (e) => {
            if (!this.touchStartX || !this.touchStartY) return;

            const touchEndX = e.changedTouches[0].clientX;
            const touchEndY = e.changedTouches[0].clientY;
            
            const deltaX = this.touchStartX - touchEndX;
            const deltaY = this.touchStartY - touchEndY;

            // Only process horizontal swipes (vertical swipes are for scrolling)
            if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > this.minSwipeDistance) {
                this.handleSwipeNavigation(deltaX > 0 ? 'left' : 'right');
            }

            // Reset touch coordinates
            this.touchStartX = 0;
            this.touchStartY = 0;
        }, { passive: true });
    }

    handleSwipeNavigation(direction) {
        const currentScreen = document.querySelector('.screen.active').id;
        
        // Swipe right (back gesture)
        if (direction === 'right') {
            if (currentScreen === 'chapter') {
                this.backToStory();
            } else if (currentScreen === 'story') {
                this.goHome();
            }
            
            // Hide swipe hint after first use
            this.hideSwipeHint();
            
            // Add haptic feedback for navigation
            if ('vibrate' in navigator) {
                navigator.vibrate(30);
            }
        }
    }

    showSwipeHint() {
        if (this.isMobile) {
            const swipeHint = document.getElementById('swipe-hint');
            swipeHint.classList.remove('hidden');
            
            // Auto-hide after 5 seconds
            setTimeout(() => {
                this.hideSwipeHint();
            }, 5000);
        }
    }

    hideSwipeHint() {
        document.getElementById('swipe-hint').classList.add('hidden');
    }

    addHapticFeedback() {
        // Add haptic feedback for word taps
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('arabic-word') && 'vibrate' in navigator) {
                navigator.vibrate(50); // Light vibration
            }
        });

        // Add haptic feedback for button presses
        const buttons = document.querySelectorAll('.back-btn, .action-btn, .story-card');
        buttons.forEach(button => {
            button.addEventListener('click', () => {
                if ('vibrate' in navigator) {
                    navigator.vibrate(30);
                }
            });
        });
    }

    handleOrientationChange() {
        // Adjust layout based on orientation
        const isLandscape = window.orientation === 90 || window.orientation === -90;
        
        if (isLandscape && this.isMobile) {
            // Optimize for landscape mode
            document.body.classList.add('landscape-mobile');
        } else {
            document.body.classList.remove('landscape-mobile');
        }
        
        // Re-trigger any layout calculations
        this.updateArabicText();
    }

    // Progress tracking methods
    loadProgress() {
        const saved = localStorage.getItem('qasas-progress');
        return saved ? JSON.parse(saved) : {};
    }

    saveProgress() {
        localStorage.setItem('qasas-progress', JSON.stringify(this.progress));
    }

    markChapterComplete() {
        if (!this.currentStory || !this.currentChapter) return;

        const storyId = this.currentStory.id;
        const chapterOrder = this.currentChapter.order || this.currentChapter.chapterOrder;

        if (!this.progress[storyId]) {
            this.progress[storyId] = [];
        }

        if (!this.progress[storyId].includes(chapterOrder)) {
            this.progress[storyId].push(chapterOrder);
            this.saveProgress();
            this.updateCompleteButton();
            
            // Add haptic feedback
            if ('vibrate' in navigator) {
                navigator.vibrate(50);
            }

            // Show completion message
            this.showCompletionMessage();
        }
    }

    isChapterCompleted(storyId, chapterOrder) {
        return this.progress[storyId] && this.progress[storyId].includes(chapterOrder);
    }

    getCompletedChaptersCount(storyId) {
        return this.progress[storyId] ? this.progress[storyId].length : 0;
    }

    updateCompleteButton() {
        const btn = document.getElementById('mark-complete-btn');
        const isCompleted = this.isChapterCompleted(
            this.currentStory.id,
            this.currentChapter.order || this.currentChapter.chapterOrder
        );

        if (isCompleted) {
            btn.textContent = '✓ Chapter Completed';
            btn.classList.add('completed');
            btn.disabled = true;
        } else {
            btn.textContent = 'Mark Chapter as Complete';
            btn.classList.remove('completed');
            btn.disabled = false;
        }
    }

    showCompletionMessage() {
        // Create completion message
        const message = document.createElement('div');
        message.className = 'completion-message';
        message.innerHTML = '✓ Chapter completed!';
        document.body.appendChild(message);

        // Show with animation
        setTimeout(() => {
            message.classList.add('show');
        }, 10);

        // Remove after 3 seconds
        setTimeout(() => {
            message.classList.remove('show');
            setTimeout(() => {
                document.body.removeChild(message);
            }, 300);
        }, 3000);
    }
}

document.addEventListener('DOMContentLoaded', () => {
    const app = new ArabicStoriesApp();

    document.addEventListener('click', (e) => {
        if (e.target.classList.contains('arabic-word')) {
            app.showWordTooltip(e);
        }
    });
});
