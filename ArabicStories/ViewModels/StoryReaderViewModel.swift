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
    var selectedWord: Word?
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
    
    // Quran words cache for highlighting
    private var quranWords: [QuranWord] = []
    var hasLoadedQuranWords = false
    
    // Quran words found in this story's text
    var quranWordsInStory: [QuranWord] = []
    
    // Trigger UI refresh when generic words load
    var onGenericWordsLoaded: (() -> Void)?
    
    // Mixed format state
    var learnedWordIdsInSession: Set<String> = []
    
    // Reading Time Tracking
    private var readingSessionStartTime: Date?
    private var currentSessionDuration: TimeInterval = 0
    private var readingTimer: Timer?
    
    // Story Completion Summary
    var showCompletionSummary = false
    var completionResult: StoryCompletionResult?
    
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
    
    /// Check if a word has a meaning available (in story words or Quran words)
    func hasMeaningAvailable(for wordText: String) -> Bool {
        // Check story words first
        if let storyWords = story.words {
            let hasStoryMatch = storyWords.contains { word in
                ArabicTextUtils.wordsMatch(word.arabicText, wordText)
            }
            if hasStoryMatch { return true }
        }
        
        // Check Quran words with normalization
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
        await updateStoryProgress()
    }
    
    func goToPreviousSegment() async {
        guard canGoPrevious else { return }
        currentSegmentIndex -= 1
        await updateStoryProgress()
    }
    
    func goToSegment(_ index: Int) async {
        guard index >= 0 && index < totalSegments else { return }
        currentSegmentIndex = index
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
        
        // Print all available words in the story
        if let words = story.words, !words.isEmpty {
            print("📚 Story has \(words.count) words:")
            for word in words {
                print("   - '\(word.arabicText)' -> '\(word.englishMeaning)'")
            }
        } else {
            print("⚠️ Story has no words defined")
        }
        
        // Find the word in the story's vocabulary first (with Arabic normalization)
        let normalizedSearch = ArabicTextUtils.normalizeForMatching(wordText)
        print("🔍 Looking for match: '\(wordText)' (normalized: '\(normalizedSearch)')")
        
        if let word = story.words?.first(where: { 
            ArabicTextUtils.wordsMatch($0.arabicText, wordText)
        }) {
            print("✅ Found word match in story: '\(word.arabicText)' = '\(word.englishMeaning)'")
            showWordDetails(word: word, position: position)
        } else {
            print("❌ No word match found in story for '\(wordText)'")
            print("🔍 Searching in generic words collection...")
            
            // Search in Quran words
            Task {
                await searchQuranWords(wordText, position: position)
            }
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
                // Show original tapped text as unknown word (simple popover)
                let unknownWord = Word(
                    arabicText: arabicText,
                    englishMeaning: "Unknown word",
                    difficulty: 1
                )
                showWordDetails(word: unknownWord, position: position)
            }
        }
    }
    
    /// Show word details in popover
    private func showWordDetails(word: Word, position: CGPoint) {
        selectedWord = word
        selectedMixedWord = nil
        popoverPosition = position
        showWordPopover = true
        
        // Mark word as learned (only if it's from story or known generic word)
        if word.englishMeaning != "Unknown word" {
            var updatedStory = story
            updatedStory.markWordAsLearned(word.id.uuidString)
            story = updatedStory
            
            Task {
                // Save story progress and update global vocabulary
                try? await dataService.saveStory(story)
                // Fetch QuranWord and record as learned
                if let quranWord = quranWordsInStory.first(where: { $0.id == word.id.uuidString }) {
                    await dataService.recordVocabularyLearned(quranWord)
                }
                // Note: Level 2 is unlocked by completing all Level 1 stories, not by vocabulary
            }
        }
    }
    
    /// Show Quran word details in full detail view
    private func showWordDetails(quranWord: QuranWord, position: CGPoint) {
        selectedQuranWord = quranWord
        showQuranWordDetail = true
        
        // Mark word as learned
        var updatedStory = story
        updatedStory.markWordAsLearned(quranWord.id)
        story = updatedStory
        
        Task {
            // Save story progress and update global vocabulary
            try? await dataService.saveStory(story)
            await dataService.recordVocabularyLearned(quranWord)
        }
    }
    
    // MARK: - Mixed Format Word Interaction
    
    func handleMixedWordTap(wordId: String, position: CGPoint) {
        let selection = UISelectionFeedbackGenerator()
        selection.selectionChanged()
        print("👆 Mixed format word tapped (ID: \(wordId))")
        
        // Find word details from story's vocabulary
        guard let word = story.words?.first(where: { $0.id.uuidString == wordId }) else {
            print("⚠️ Word not found in story vocabulary: \(wordId)")
            return
        }
        
        let mixedInfo = MixedWordInfo(
            wordId: wordId,
            arabicText: word.arabicText,
            transliteration: word.transliteration,
            englishMeaning: word.englishMeaning
        )
        
        selectedMixedWord = mixedInfo
        selectedWord = word
        popoverPosition = position
        showWordPopover = true
        
        // Mark as learned
        if !learnedWordIdsInSession.contains(wordId) {
            learnedWordIdsInSession.insert(wordId)
            
            var updatedStory = story
            updatedStory.markWordAsLearned(wordId)
            story = updatedStory
            
            Task {
                try? await dataService.saveStory(story)
                // Fetch QuranWord and record as learned
                if let quranWord = quranWordsInStory.first(where: { $0.id == wordId }) {
                    await dataService.recordVocabularyLearned(quranWord)
                }
                // Note: Level 2 is unlocked by completing all Level 1 stories, not by vocabulary
            }
        }
    }
    
    func isMixedWordLearned(_ wordId: String) -> Bool {
        story.isWordLearned(wordId) || learnedWordIdsInSession.contains(wordId)
    }
    
    func isWordLearned(_ wordId: String) -> Bool {
        story.isWordLearned(wordId)
    }
    
    func toggleWordBookmark(_ word: Word) {
        // Implementation for bookmarking word - would need to be saved to user progress
        // For now, just a placeholder
    }
    
    func playWordPronunciation(_ word: Word) {
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
        
        // Save completion to user-specific story progress
        print("📖 Complete story: Saving story progress...")
        await dataService.updateStoryProgress(
            storyId: story.id,
            readingProgress: 1.0,
            currentSegmentIndex: currentSegmentIndex
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
        
        // Track story completion via Firebase function
        print("📖 Complete story: Tracking completion via API...")
        await trackStoryCompletion()
        print("📖 Complete story: API tracking completed")
        
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
    
    /// Extract Quran words from story and save to user's learned vocabulary
    private func extractAndSaveUnlockedWords() async {
        // Load Quran words from offline bundle for matching
        let quranWords = OfflineDataService.shared.loadQuranWords()
        
        // Use Story's algorithm to find Quran words in story text
        let matchedQuranWords = story.findQuranWordsInStory(from: quranWords)
        print("📖 Complete story: Found \(matchedQuranWords.count) Quran words in story")
        
        // Save matched Quran words directly to learnedQuranWords collection
        var newWordsCount = 0
        for quranWord in matchedQuranWords {
            // Check if word is already learned (avoid duplicates)
            let isAlreadyLearned = await dataService.isQuranWordLearned(quranWord.id)
            if !isAlreadyLearned {
                await dataService.recordVocabularyLearned(quranWord)
                newWordsCount += 1
            }
        }
        
        if newWordsCount > 0 {
            print("📖 Complete story: Saved \(newWordsCount) new Quran words to learned vocabulary")
        } else {
            print("📖 Complete story: No new words to save (all already learned)")
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

        // Get words unlocked in this session
        let wordsUnlocked = getWordsUnlockedInSession()
        print("📖 Complete story: Found \(wordsUnlocked.count) words unlocked in session")

        // Get total words in story (use same logic as library view cells)
        let totalWords = story.arabicWordCount

        // Create completion result
        let result = StoryCompletionResult(
            story: story,
            unlockedAchievements: newlyUnlockedAchievements,
            totalWordsInStory: totalWords,
            wordsUnlockedInSession: wordsUnlocked,
            readingTime: currentSessionDuration
        )
        
        print("📖 Complete story: prepareCompletionSummary() finished")
        return result
    }
    
    /// Get the words that were unlocked/learned during this reading session
    private func getWordsUnlockedInSession() -> [Word] {
        guard let storyWords = story.words else { return [] }
        
        // Get words that were learned in this session
        let sessionWordIds = learnedWordIdsInSession
        
        // Also include words that were already marked as learned in the story
        let learnedIds = story.learnedWordIds ?? []
        let allLearnedIds = sessionWordIds.union(Set(learnedIds))
        
        return storyWords.filter { word in
            allLearnedIds.contains(word.id.uuidString)
        }
    }
    
    /// Dismiss the completion summary and reset state
    func dismissCompletionSummary() {
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
        guard let words = story.words, !words.isEmpty else { return 0 }
        let learned = story.learnedVocabularyCount
        return Double(learned) / Double(words.count)
    }
    
    var learnedVocabularyCount: Int {
        story.learnedVocabularyCount + learnedWordIdsInSession.count
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
