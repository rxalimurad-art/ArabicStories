//
//  StoryReaderViewModel.swift
//  Arabicly
//  ViewModel for the Story Reader with audio sync and mixed content support
//

import Foundation
import SwiftUI
import FirebaseAuth

@Observable
class StoryReaderViewModel {
    // Dependencies
    private let dataService = DataService.shared
    private let audioService = AudioService.shared
    private let pronunciationService = PronunciationService.shared
    private let firebaseService = FirebaseService.shared
    
    // State
    var story: Story
    var currentSegmentIndex: Int = 0
    var isLoading = false
    var isCompletingStory = false  // For showing progress when completing story
    
    // Audio State
    var isPlaying = false
    var audioProgress: Double = 0.0
    var currentAudioTime: TimeInterval = 0
    var audioDuration: TimeInterval = 0
    var currentHighlightWordIndex: Int = -1
    var playbackSpeed: AudioSpeed = .normal
    
    // Word Popover State
    var selectedWord: QuranWord?
    var selectedQuranWord: QuranWord?      // For Quran words from quran_words collection
    var showWordPopover = false
    var showQuranWordDetail = false        // Show full QuranWordDetailView
    var popoverPosition: CGPoint = .zero
    var selectedMixedWord: MixedWordInfo?  // For mixed format
    
    // Settings
    var fontSize: CGFloat = 20
    var arabicFont: ArabicFont = .notoNaskh
    var isNightMode = false
    var showEnglish = true
    var showTransliteration = true
    var autoScrollEnabled = true
    
    // Quran words cache for highlighting - accessible to views
    var quranWords: [QuranWord] = []
    var hasLoadedQuranWords = false
    
    // Quran words found in this story's text
    var quranWordsInStory: [QuranWord] = []
    
    // Trigger UI refresh when generic words load
    var onGenericWordsLoaded: (() -> Void)?
    
    // Trigger UI refresh when vocabulary progress changes
    var vocabularyProgressUpdated: (() -> Void)?
    
    // Mixed format state
    var learnedWordIdsInSession: Set<String> = []
    
    // Auto-learn tracking - words learned by appearing on screen
    private var autoLearnedWordIds: Set<String> = []
    private var hasAutoLearnedForCurrentSegment = false
    
    // Words pending save - only saved when story is completed
    private var pendingLearnedWords: [QuranWord] = []
    
    // Reading Time Tracking
    private var readingSessionStartTime: Date?
    private var currentSessionDuration: TimeInterval = 0
    private var readingTimer: Timer?
    
    // Story Completion Summary
    var showCompletionSummary = false
    var completionResult: StoryCompletionResult?
    var onLevelCompleted: ((Int) -> Void)?  // Callback when level is completed (passes next level number)
    
    struct MixedWordInfo {
        let wordId: String
        let arabicText: String
        let transliteration: String?
        let englishMeaning: String?
    }
    
    init(story: Story, wasReset: Bool = false) {
        self.story = story
        self.currentSegmentIndex = 0 // Default to start
        setupAudioCallbacks()
        
        // Debug: Print story info
        print("📖 StoryReaderViewModel initialized")
        print("   Story: '\(story.title)'")
        print("   Format: \(story.format.rawValue)")
        print("   Segments: \(story.segments?.count ?? 0)")
        print("   Mixed Segments: \(story.mixedSegments?.count ?? 0)")
        print("   Arabic words in story: \(story.allArabicWordsInStory.count)")
        print("   Was reset: \(wasReset)")
        
        // Load user-specific progress
        Task {
            if let progress = await DataService.shared.fetchStoryProgress(storyId: story.id) {
                // If story is completed and not being reset, start from beginning
                if progress.isCompleted && !wasReset {
                    // Keep at 0 (start over)
                    print("📖 Story completed, starting from beginning")
                } else {
                    // Resume from saved progress
                    await MainActor.run {
                        self.currentSegmentIndex = progress.currentSegmentIndex
                    }
                    print("📖 Resumed from segment \(progress.currentSegmentIndex)")
                }
            }
        }
        
        // Pre-load Quran words for highlighting
        Task {
            await preloadQuranWords()
        }
    }
    
    /// Pre-load all Quran words to enable highlighting and find words in story
    private func preloadQuranWords() async {
        // Load Quran words from offline bundle
        quranWords = OfflineDataService.shared.loadQuranWords()
        hasLoadedQuranWords = true
        print("✅ Pre-loaded \(quranWords.count) Quran words for highlighting")
        
        // Find Quran words that exist in this story's text
        let matchedWords = story.findQuranWordsInStory(from: quranWords)
        await MainActor.run {
            self.quranWordsInStory = matchedWords
            print("📖 Found \(matchedWords.count) Quran words in story '\(self.story.title)':")
            for word in matchedWords.prefix(10) {
                print("   - '\(word.arabicText)' = '\(word.englishMeaning)' (rank: \(word.rank))")
            }
            if matchedWords.count > 10 {
                print("   ... and \(matchedWords.count - 10) more")
            }
        }
        
        // Notify UI to refresh highlighting
        await MainActor.run {
            self.onGenericWordsLoaded?()
        }
    }
    
    // MARK: - Auto-Learn Words on Screen
    
    /// Automatically mark words as learned when they appear on screen
    /// Call this when a segment is displayed
    func autoLearnWordsForCurrentSegment() {
        guard !hasAutoLearnedForCurrentSegment else { return }
        
        let wordsToLearn: [String]
        
        if story.format == .mixed, let segment = currentMixedSegment {
            // For mixed format: extract Arabic words from segment text
            wordsToLearn = extractLearnableWords(from: segment.text)
        } else if story.format == .bilingual, let segment = currentSegment {
            // For bilingual format: learn Arabic words that have meanings
            wordsToLearn = extractLearnableWords(from: segment.arabicText)
        } else {
            return
        }
        
        guard !wordsToLearn.isEmpty else { return }
        
        print("📚 Auto-learning \(wordsToLearn.count) words for segment \(currentSegmentIndex)")
        
        for wordId in wordsToLearn {
            autoLearnWord(wordId)
        }
        
        hasAutoLearnedForCurrentSegment = true
    }
    
    /// Reset auto-learn flag when navigating to a new segment
    func resetAutoLearnForNewSegment() {
        hasAutoLearnedForCurrentSegment = false
    }
    
    /// Extract learnable Arabic words from text
    private func extractLearnableWords(from text: String) -> [String] {
        var words: [String] = []
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            let char = text[currentIndex]
            
            if ArabicTextUtils.isArabicCharacter(char) {
                var arabicWord = ""
                var endIndex = currentIndex
                
                while endIndex < text.endIndex &&
                      (ArabicTextUtils.isArabicCharacter(text[endIndex]) ||
                       ArabicTextUtils.isDiacritic(text[endIndex])) {
                    arabicWord.append(text[endIndex])
                    endIndex = text.index(after: endIndex)
                }
                
                if !arabicWord.isEmpty && hasMeaningAvailable(for: arabicWord) {
                    // Find the Quran word ID for this Arabic text
                    if let quranWord = quranWords.first(where: { 
                        ArabicTextUtils.wordsMatch($0.arabicText, arabicWord)
                    }) {
                        if !words.contains(quranWord.id) {
                            words.append(quranWord.id)
                        }
                    }
                }
                currentIndex = endIndex
            } else {
                currentIndex = text.index(after: currentIndex)
            }
        }
        
        return words
    }
    
    /// Auto-learn a word by its ID (without requiring user tap)
    /// Words are tracked locally but NOT saved to Firebase until story is completed
    private func autoLearnWord(_ wordId: String) {
        // Skip if already learned in this session or previously
        if learnedWordIdsInSession.contains(wordId) || story.isWordLearned(wordId) {
            return
        }
        
        // Skip if already auto-learned
        if autoLearnedWordIds.contains(wordId) {
            return
        }
        
        autoLearnedWordIds.insert(wordId)
        learnedWordIdsInSession.insert(wordId)
        
        // Mark in story
        var updatedStory = story
        updatedStory.markWordAsLearned(wordId)
        story = updatedStory
        
        // Track locally but DON'T save to Firebase yet - only save when story completes
        if let quranWord = quranWords.first(where: { $0.id == wordId }) {
            if !pendingLearnedWords.contains(where: { $0.id == wordId }) {
                pendingLearnedWords.append(quranWord)
                print("📚 Queued word for learning on story completion: '\(quranWord.arabicText)' = '\(quranWord.englishMeaning)'")
            }
        } else if let quranWord = quranWordsInStory.first(where: { $0.id == wordId }) {
            if !pendingLearnedWords.contains(where: { $0.id == wordId }) {
                pendingLearnedWords.append(quranWord)
                print("📚 Queued story word for learning on story completion: '\(quranWord.arabicText)' = '\(quranWord.englishMeaning)'")
            }
        }
        
        // Notify UI to refresh vocabulary progress
        vocabularyProgressUpdated?()
    }
    
    /// Get all learned word IDs (from story + session + auto-learned)
    var allLearnedWordIds: Set<String> {
        var all = Set(story.learnedWordIds ?? [])
        all.formUnion(learnedWordIdsInSession)
        all.formUnion(autoLearnedWordIds)
        return all
    }
    
    /// Check if a word has a meaning available (in story words or Quran words)
    func hasMeaningAvailable(for wordText: String) -> Bool {
        // Only highlight words that exist in the Quran words collection
        // This ensures users only tap on words with proper Quran definitions
        let hasQuranMatch = quranWords.contains { quranWord in
            ArabicTextUtils.wordsMatch(quranWord.arabicText, wordText)
        }
        
        return hasQuranMatch
    }
    
    // MARK: - Computed Properties
    
    var currentSegment: StorySegment? {
        guard story.format == .bilingual,
              let segments = story.segments,
              currentSegmentIndex < segments.count else { return nil }
        return segments.sorted { $0.index < $1.index }[currentSegmentIndex]
    }
    
    var currentMixedSegment: MixedContentSegment? {
        guard story.format == .mixed,
              let segments = story.mixedSegments,
              currentSegmentIndex < segments.count else { return nil }
        return segments.sorted { $0.index < $1.index }[currentSegmentIndex]
    }
    
    var totalSegments: Int {
        switch story.format {
        case .mixed:
            return story.mixedSegments?.count ?? 0
        case .bilingual:
            return story.segments?.count ?? 0
        }
    }
    
    var readingProgress: Double {
        guard totalSegments > 0 else { return 0 }
        // Progress based on completed segments (current + 1) / total
        return Double(currentSegmentIndex + 1) / Double(totalSegments)
    }
    
    var canGoNext: Bool {
        currentSegmentIndex < totalSegments - 1
    }
    
    var canGoPrevious: Bool {
        currentSegmentIndex > 0
    }
    
    var isMixedFormat: Bool {
        story.format == .mixed
    }
    
    // MARK: - Navigation
    
    func goToNextSegment() async {
        guard canGoNext else { 
            // Mark story as completed when reaching the end
            await completeStory()
            return 
        }
        currentSegmentIndex += 1
        hasAutoLearnedForCurrentSegment = false  // Reset for new segment
        await updateStoryProgress()
    }
    
    func goToPreviousSegment() async {
        guard canGoPrevious else { return }
        currentSegmentIndex -= 1
        hasAutoLearnedForCurrentSegment = false  // Reset for new segment
        await updateStoryProgress()
    }
    
    func goToSegment(_ index: Int) async {
        guard index >= 0 && index < totalSegments else { return }
        currentSegmentIndex = index
        hasAutoLearnedForCurrentSegment = false  // Reset for new segment
        await updateStoryProgress()
    }
    
    // MARK: - Audio Control
    
    func togglePlayback() {
        if audioService.isPlaying {
            pauseAudio()
        } else {
            playAudio()
        }
    }
    
    func playAudio() {
        audioService.play()
        isPlaying = true
    }
    
    func pauseAudio() {
        audioService.pause()
        isPlaying = false
    }
    
    func setPlaybackSpeed(_ speed: AudioSpeed) {
        playbackSpeed = speed
        audioService.setSpeed(speed)
    }
    
    private func setupAudioCallbacks() {
        audioService.onWordHighlighted = { [weak self] index, timing in
            DispatchQueue.main.async {
                self?.currentHighlightWordIndex = index
            }
        }
        
        audioService.onPlaybackFinished = { [weak self] in
            DispatchQueue.main.async {
                self?.isPlaying = false
            }
        }
    }
    
    // MARK: - Word Interaction (Bilingual Format)
    
    func handleWordTap(wordText: String, position: CGPoint) {
        let selection = UISelectionFeedbackGenerator()
        selection.selectionChanged()
        print("👆 Word tapped: '\(wordText)'")
        
        // Search in Quran words directly - quran_words.json is the single source of truth
        let normalizedSearch = ArabicTextUtils.normalizeForMatching(wordText)
        print("🔍 Looking for match: '\(wordText)' (normalized: '\(normalizedSearch)')")
        print("🔍 Searching in Quran words collection...")
        
        Task {
            await searchQuranWords(wordText, position: position)
        }
    }
    
    /// Search for word in the Quran words collection
    private func searchQuranWords(_ arabicText: String, position: CGPoint) async {
        // First search in cached quranWords (same as hasMeaningAvailable uses)
        if let cachedMatch = quranWords.first(where: { 
            ArabicTextUtils.wordsMatch($0.arabicText, arabicText) 
        }) {
            await MainActor.run {
                print("✅ Found word match in cached Quran words: '\(cachedMatch.arabicText)' = '\(cachedMatch.englishMeaning)'")
                showWordDetails(quranWord: cachedMatch, position: position)
            }
            return
        }
        
        // If not in cache, try offline bundle search
        if let quranWord = OfflineDataService.shared.findQuranWordByArabic(arabicText) {
            await MainActor.run {
                print("✅ Found word match in offline bundle: '\(quranWord.arabicText)' = '\(quranWord.englishMeaning)'")
                showWordDetails(quranWord: quranWord, position: position)
            }
        } else {
            await MainActor.run {
                print("❌ No word match found for '\(arabicText)'")
                // Create a simple QuranWord for unknown words
                let unknownWord = QuranWord(
                    id: "unknown-\(arabicText)",
                    rank: 999999,
                    arabicText: arabicText,
                    arabicWithoutDiacritics: ArabicTextUtils.stripDiacritics(arabicText),
                    buckwalter: nil,
                    englishMeaning: "Unknown word",
                    root: nil,
                    morphology: QuranMorphology(partOfSpeech: nil, passive: false),
                    occurrenceCount: 0
                )
                showWordDetails(quranWord: unknownWord, position: position)
            }
        }
    }
    
    /// Show Quran word details in full detail view
    private func showWordDetails(quranWord: QuranWord, position: CGPoint) {
        selectedQuranWord = quranWord
        showQuranWordDetail = true
        
        // Mark word as learned locally
        var updatedStory = story
        updatedStory.markWordAsLearned(quranWord.id)
        story = updatedStory
        
        // Queue for saving on story completion
        if !pendingLearnedWords.contains(where: { $0.id == quranWord.id }) {
            pendingLearnedWords.append(quranWord)
            print("📚 Queued tapped Quran word for learning on story completion: '\(quranWord.arabicText)'")
        }
        
        // Save story progress locally
        Task {
            try? await dataService.saveStory(story)
        }
    }
    
    // MARK: - Mixed Format Word Interaction
    
    func handleMixedWordTap(wordId: String, position: CGPoint) {
        let selection = UISelectionFeedbackGenerator()
        selection.selectionChanged()
        print("👆 Mixed format word tapped (ID: \(wordId))")
        
        // Find word details from Quran words - quran_words.json is single source of truth
        guard let quranWord = quranWords.first(where: { $0.id == wordId }) ?? 
                              quranWordsInStory.first(where: { $0.id == wordId }) else {
            print("⚠️ Word not found in Quran words: \(wordId)")
            return
        }
        
        // Show Quran word detail view
        selectedQuranWord = quranWord
        showQuranWordDetail = true
        
        // Mark as learned locally (but don't save to Firebase until story is completed)
        if !learnedWordIdsInSession.contains(wordId) {
            learnedWordIdsInSession.insert(wordId)
            
            var updatedStory = story
            updatedStory.markWordAsLearned(wordId)
            story = updatedStory
            
            // Queue for saving on story completion
            if !pendingLearnedWords.contains(where: { $0.id == quranWord.id }) {
                pendingLearnedWords.append(quranWord)
                print("📚 Queued mixed word for learning on story completion: '\(quranWord.arabicText)'")
            }
            
            // Save story progress locally
            Task {
                try? await dataService.saveStory(story)
            }
        }
    }
    
    func isMixedWordLearned(_ wordId: String) -> Bool {
        story.isWordLearned(wordId) || learnedWordIdsInSession.contains(wordId) || autoLearnedWordIds.contains(wordId)
    }
    
    func isWordLearned(_ wordId: String) -> Bool {
        story.isWordLearned(wordId) || autoLearnedWordIds.contains(wordId)
    }
    
    func toggleWordBookmark(_ word: QuranWord) {
        // Implementation for bookmarking word - would need to be saved to user progress
        // For now, just a placeholder
    }
    
    func playWordPronunciation(_ word: QuranWord) {
        Task {
            await pronunciationService.playPronunciation(for: word)
        }
    }
    
    func closeWordPopover() {
        showWordPopover = false
        selectedWord = nil
        selectedMixedWord = nil
    }
    
    func closeQuranWordDetail() {
        showQuranWordDetail = false
        selectedQuranWord = nil
    }
    
    // MARK: - Progress (User-Specific)
    
    private func updateStoryProgress() async {
        // Save to user-specific story progress
        await dataService.updateStoryProgress(
            storyId: story.id,
            readingProgress: readingProgress,
            currentSegmentIndex: currentSegmentIndex
        )
    }
    
    private func completeStory() async {
        print("📖 Complete story: Starting completion for '\(story.title)'")
        
        await MainActor.run {
            isCompletingStory = true
            print("📖 Complete story: Set isCompletingStory = true")
        }
        
        // Save completion to user-specific story progress (immediate save)
        print("📖 Complete story: Saving story progress...")
        await dataService.updateStoryProgress(
            storyId: story.id,
            readingProgress: 1.0,
            currentSegmentIndex: currentSegmentIndex,
            immediate: true
        )
        print("📖 Complete story: Story progress saved")
        
        // Record story completion in user progress
        print("📖 Complete story: Recording story completion...")
        let unlocked = await dataService.recordStoryCompleted(
            storyId: story.id.uuidString,
            difficultyLevel: story.difficultyLevel
        )
        if unlocked {
            print("🎉 Complete story: Level 2 Unlocked!")
        }
        print("📖 Complete story: Story completion recorded")
        
        // NEW: Extract and save unlocked words
        print("📖 Complete story: Extracting Quran words from story...")
        await extractAndSaveUnlockedWords()
        print("📖 Complete story: Words saved successfully")
        
        // Track story completion via Firebase function (skip in debug)
        #if DEBUG
        print("📖 Complete story: Skipping API tracking in DEBUG mode")
        #else
        print("📖 Complete story: Tracking completion via API...")
        await trackStoryCompletion()
        print("📖 Complete story: API tracking completed")
        #endif
        
        // Check for achievements and prepare completion summary
        print("📖 Complete story: Preparing completion summary...")
        let result = await prepareCompletionSummary()
        
        await MainActor.run {
            self.completionResult = result
            self.showCompletionSummary = true
            self.isCompletingStory = false
            print("📖 Complete story: Completion summary ready, sheet will show")
        }
        print("📖 Complete story: Finished successfully")
    }
    
    /// Extract words from story and save to user's learned vocabulary (optimized batch version)
    /// Words are looked up from quran_words.json - single source of truth
    private func extractAndSaveUnlockedWords() async {
        print("📖 Complete story: Saving unlocked words from completed story...")
        
        var allWordsToSave: [QuranWord] = []
        var wordIds = Set<String>()  // Track word IDs to avoid duplicates
        
        // 1. First, collect all pending words that were queued during reading
        for quranWord in pendingLearnedWords {
            if !wordIds.contains(quranWord.id) {
                allWordsToSave.append(quranWord)
                wordIds.insert(quranWord.id)
            }
        }
        pendingLearnedWords.removeAll()
        
        // 2. Find Quran words in story text and add them
        let storyQuranWords = story.findQuranWordsInStory(from: quranWords)
        print("📖 Complete story: Found \(storyQuranWords.count) Quran words in story text")
        for quranWord in storyQuranWords {
            if !wordIds.contains(quranWord.id) {
                allWordsToSave.append(quranWord)
                wordIds.insert(quranWord.id)
            }
        }
        
        // 3. Batch save all words at once (much faster than individual saves)
        if !allWordsToSave.isEmpty {
            print("📖 Complete story: Batch saving \(allWordsToSave.count) words...")
            let savedCount = await dataService.recordVocabularyLearnedBatch(allWordsToSave)
            print("📖 Complete story: Saved \(savedCount) new words to learned vocabulary (\(allWordsToSave.count - savedCount) were already learned)")
        } else {
            print("📖 Complete story: No new words to save")
        }
    }
    
    /// Track story completion via Firebase function
    private func trackStoryCompletion() async {
        guard let user = Auth.auth().currentUser else {
            print("⚠️ No user logged in, skipping completion tracking")
            return
        }
        
        do {
            try await firebaseService.trackStoryCompletion(
                userId: user.uid,
                userName: user.displayName,
                userEmail: user.email,
                storyId: story.id.uuidString,
                storyTitle: story.title,
                difficultyLevel: story.difficultyLevel
            )
        } catch {
            print("⚠️ Failed to track story completion: \(error)")
            // Don't fail the whole completion if tracking fails
        }
    }
    
    func markAsCompleted() async {
        print("📖 Complete story: markAsCompleted() called")
        await completeStory()
        print("📖 Complete story: markAsCompleted() finished")
    }
    
    /// Prepare the completion summary with achievements, words unlocked, and stats
    private func prepareCompletionSummary() async -> StoryCompletionResult {
        print("📖 Complete story: prepareCompletionSummary() started")
        
        // Load progress view model to check achievements
        print("📖 Complete story: Loading ProgressViewModel...")
        let progressVM = ProgressViewModel()
        await progressVM.checkAchievementsAfterStoryCompletion()
        print("📖 Complete story: ProgressViewModel check completed")
        
        // Get only achievements newly unlocked by this story
        let newlyUnlockedAchievements = progressVM.newlyUnlockedAchievements

        print("📖 Complete story: Found \(newlyUnlockedAchievements.count) newly unlocked achievements")

        // Get all Quran words found in this story (for display on completion screen)
        let allStoryWords = story.findQuranWordsInStory(from: quranWords)
        print("📖 Complete story: Found \(allStoryWords.count) Quran words in story")

        // Get total words in story (use accurate count from Quran words match)
        let totalWords = allStoryWords.count
        
        // Check if all stories in current level are completed
        let (levelCompleted, nextLevel) = await checkLevelCompletion()
        print("📖 Complete story: Level \(story.difficultyLevel) completed: \(levelCompleted), next level: \(nextLevel ?? -1)")

        // Create completion result
        let result = StoryCompletionResult(
            story: story,
            unlockedAchievements: newlyUnlockedAchievements,
            totalWordsInStory: totalWords,
            wordsUnlockedInSession: allStoryWords,
            readingTime: currentSessionDuration,
            levelCompleted: levelCompleted,
            nextLevel: nextLevel
        )
        
        print("📖 Complete story: prepareCompletionSummary() finished")
        return result
    }
    
    /// Check if all stories in the current level are completed
    /// Returns (isLevelCompleted, nextLevelNumber)
    private func checkLevelCompletion() async -> (Bool, Int?) {
        let currentLevel = story.difficultyLevel
        
        // Fetch all stories for the current level
        let allStories = await dataService.fetchAllStories()
        let levelStories = allStories.filter { $0.difficultyLevel == currentLevel }
        
        // Get all completed story IDs
        let allProgress = await dataService.getAllStoryProgress()
        let completedStoryIds = Set(allProgress.filter { $0.isCompleted }.map { $0.storyId })
        
        // Check if all level stories are completed
        let allCompleted = levelStories.allSatisfy { completedStoryIds.contains($0.id.uuidString) }
        
        if allCompleted {
            let nextLevel = currentLevel + 1
            // Unlock the next level
            await dataService.unlockLevel(nextLevel)
            return (true, nextLevel)
        }
        
        return (false, nil)
    }
    
    /// Get the words that were unlocked/learned during this reading session
    private func getWordsUnlockedInSession() -> [QuranWord] {
        // Get all learned word IDs (story + session + auto-learned)
        let allLearnedIds = allLearnedWordIds
        
        // Return QuranWord objects for all learned words
        return allLearnedIds.compactMap { wordId in
            quranWords.first { $0.id == wordId } ?? 
            quranWordsInStory.first { $0.id == wordId }
        }
    }
    
    /// Dismiss the completion summary and reset state
    func dismissCompletionSummary() {
        // Check if level was completed and trigger callback
        if let result = completionResult, result.levelCompleted, let nextLevel = result.nextLevel {
            onLevelCompleted?(nextLevel)
        }
        showCompletionSummary = false
        completionResult = nil
    }
    
    // MARK: - Settings
    
    func toggleNightMode() {
        isNightMode.toggle()
    }
    
    func toggleEnglish() {
        showEnglish.toggle()
    }
    
    func toggleTransliteration() {
        showTransliteration.toggle()
    }
    
    func resetProgress() {
        currentSegmentIndex = 0
        learnedWordIdsInSession.removeAll()
        
        Task {
            // Reset user-specific story progress
            var storyProgress = await dataService.fetchStoryProgress(storyId: story.id)
                ?? StoryProgress(storyId: story.id.uuidString, userId: "")
            storyProgress.reset()
            await dataService.updateStoryProgress(
                storyId: story.id,
                readingProgress: 0.0,
                currentSegmentIndex: 0
            )
        }
    }
    
    func incrementViewCount() {
        var updatedStory = story
        updatedStory.incrementViewCount()
        story = updatedStory
        
        Task {
            try? await dataService.saveStory(story)
        }
    }
    
    // MARK: - Vocabulary Progress
    
    var vocabularyProgress: Double {
        let totalWords = story.vocabularyCount
        guard totalWords > 0 else { return 0 }
        let learned = allLearnedWordIds.count
        return Double(learned) / Double(totalWords)
    }
    
    var learnedVocabularyCount: Int {
        // Include story learned words + session learned + auto-learned
        allLearnedWordIds.count
    }
    
    var totalVocabularyCount: Int {
        story.vocabularyCount
    }
    
    // MARK: - Reading Time Tracking
    
    /// Formatted reading time for display (updates in real-time)
    var formattedCurrentSessionTime: String {
        let totalSeconds = Int(currentSessionDuration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "0:%02d", seconds)
        }
    }
    
    /// Start tracking reading time for this session
    func startReadingSession() {
        guard readingSessionStartTime == nil else { return }
        readingSessionStartTime = Date()
        currentSessionDuration = 0
        
        // Start a timer to update current session duration every second
        readingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.currentSessionDuration += 1
        }
        
        print("⏱️ Started reading session for '\(story.title)'")
    }
    
    /// Stop tracking and save accumulated reading time
    func stopReadingSession() async {
        guard let startTime = readingSessionStartTime else { return }
        
        // Invalidate timer
        readingTimer?.invalidate()
        readingTimer = nil
        
        // Calculate elapsed time
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Reset session tracking
        readingSessionStartTime = nil
        currentSessionDuration = 0
        
        // Save to user-specific story progress and user progress
        await dataService.updateStoryProgress(
            storyId: story.id,
            readingTime: elapsed
        )
        // Also record to user progress for dashboard stats
        await dataService.recordReadingTime(storyId: story.id, timeInterval: elapsed)
        print("⏱️ Saved reading time: \(Int(elapsed))s")
    }
    
    /// Get formatted reading time for display
    var formattedReadingTime: String {
        let totalSeconds = Int(story.totalReadingTime + currentSessionDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    /// Get total reading time in seconds
    var totalReadingTimeSeconds: TimeInterval {
        story.totalReadingTime + currentSessionDuration
    }
}

// MARK: - Arabic Font Options

enum ArabicFont: String, CaseIterable, Identifiable {
    case geezaPro = "Geeza Pro"
    case alNile = "Al Nile"
    case damascus = "Damascus"
    case baghdad = "Baghdad"
    case notoNaskh = "Noto Naskh Arabic"

    var id: String { rawValue }

    /// The actual iOS font family name used with UIFont / Font.custom
    var fontName: String {
        switch self {
        case .geezaPro:
            return "GeezaPro"
        case .alNile:
            return "AlNile"
        case .damascus:
            return "Damascus"
        case .baghdad:
            return "Baghdad"
        case .notoNaskh:
            return "NotoNaskhArabic"
        }
    }

    var swiftUIFont: Font {
        .custom(fontName, size: 20)
    }
}
