//
//  StoryReaderViewModel.swift
//  Arabicly
//  ViewModel for the Story Reader with audio sync and mixed content support
//

import Foundation
import SwiftUI

@Observable
class StoryReaderViewModel {
    // Dependencies
    private let dataService = DataService.shared
    private let audioService = AudioService.shared
    private let pronunciationService = PronunciationService.shared
    
    // State
    var story: Story
    var currentSegmentIndex: Int = 0
    var isLoading = false
    
    // Audio State
    var isPlaying = false
    var audioProgress: Double = 0.0
    var currentAudioTime: TimeInterval = 0
    var audioDuration: TimeInterval = 0
    var currentHighlightWordIndex: Int = -1
    var playbackSpeed: AudioSpeed = .normal
    
    // Word Popover State
    var selectedWord: Word?
    var showWordPopover = false
    var popoverPosition: CGPoint = .zero
    var selectedMixedWord: MixedWordInfo?  // For mixed format
    
    // Settings
    var fontSize: CGFloat = 20
    var isNightMode = false
    var showEnglish = true
    var showTransliteration = true
    var autoScrollEnabled = true
    
    // Generic words cache for highlighting
    private var genericWords: [Word] = []
    var hasLoadedGenericWords = false
    
    // Trigger UI refresh when generic words load
    var onGenericWordsLoaded: (() -> Void)?
    
    // Mixed format state
    var learnedWordIdsInSession: Set<String> = []
    
    struct MixedWordInfo {
        let wordId: String
        let arabicText: String
        let transliteration: String?
        let englishMeaning: String?
    }
    
    init(story: Story, wasReset: Bool = false) {
        self.story = story
        self.currentSegmentIndex = story.currentSegmentIndex
        setupAudioCallbacks()
        
        // Debug: Print story info
        print("📖 StoryReaderViewModel initialized")
        print("   Story: '\(story.title)'")
        print("   Format: \(story.format.rawValue)")
        print("   Segments: \(story.segments?.count ?? 0)")
        print("   Mixed Segments: \(story.mixedSegments?.count ?? 0)")
        print("   Words: \(story.words?.count ?? 0)")
        print("   Was reset: \(wasReset)")
        if let words = story.words {
            for word in words {
                print("   - Word: '\(word.arabicText)' = '\(word.englishMeaning)'")
            }
        }
        
        // If story was reset (completed and restarted), save the reset state
        if wasReset {
            Task {
                try? await DataService.shared.saveStory(story)
                print("✅ Saved reset story progress")
            }
        }
        
        // Pre-load generic words for highlighting
        Task {
            await preloadGenericWords()
        }
    }
    
    /// Pre-load all generic words to enable highlighting
    private func preloadGenericWords() async {
        do {
            genericWords = try await FirebaseService.shared.fetchGenericWords()
            hasLoadedGenericWords = true
            print("✅ Pre-loaded \(genericWords.count) generic words for highlighting")
            
            // Notify UI to refresh highlighting
            await MainActor.run {
                self.onGenericWordsLoaded?()
            }
        } catch {
            print("❌ Failed to preload generic words: \(error)")
        }
    }
    
    /// Check if a word has a meaning available (in story words or generic words)
    func hasMeaningAvailable(for wordText: String) -> Bool {
        let normalizedSearch = ArabicTextUtils.normalizeForMatching(wordText)
        
        // Check story words first
        if let storyWords = story.words {
            let hasStoryMatch = storyWords.contains { word in
                ArabicTextUtils.wordsMatch(word.arabicText, wordText)
            }
            if hasStoryMatch { return true }
        }
        
        // Check generic words with normalization
        let hasGenericMatch = genericWords.contains { word in
            ArabicTextUtils.wordsMatch(word.arabicText, wordText)
        }
        
        return hasGenericMatch
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
            
            // Search in generic words
            Task {
                await searchGenericWords(wordText, position: position)
            }
        }
    }
    
    /// Search for word in the generic words collection
    private func searchGenericWords(_ arabicText: String, position: CGPoint) async {
        do {
            let matches = try await FirebaseService.shared.searchGenericWords(arabicText: arabicText)
            
            await MainActor.run {
                if let firstMatch = matches.first {
                    print("✅ Found word match in generic words: '\(firstMatch.arabicText)' = '\(firstMatch.englishMeaning)'")
                    showWordDetails(word: firstMatch, position: position)
                } else {
                    print("❌ No word match found in generic words for '\(arabicText)'")
                    
                    // Show original tapped text (not normalized) in the popover
                    let unknownWord = Word(
                        arabicText: arabicText,
                        englishMeaning: "Unknown word",
                        difficulty: 1
                    )
                    showWordDetails(word: unknownWord, position: position)
                }
            }
        } catch {
            print("❌ Error searching generic words: \(error)")
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
                await dataService.recordVocabularyLearned(wordId: word.id.uuidString)
                // Note: Level 2 is unlocked by completing all Level 1 stories, not by vocabulary
            }
        }
    }
    
    // MARK: - Mixed Format Word Interaction
    
    func handleMixedWordTap(wordId: String, position: CGPoint) {
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
                await dataService.recordVocabularyLearned(wordId: wordId)
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
    
    // MARK: - Progress
    
    private func updateStoryProgress() async {
        var updatedStory = story
        updatedStory.currentSegmentIndex = currentSegmentIndex
        updatedStory.updateProgress(readingProgress)
        story = updatedStory
        
        do {
            try await dataService.saveStory(story)
        } catch {
            print("Error saving progress: \(error)")
        }
    }
    
    private func completeStory() async {
        var updatedStory = story
        updatedStory.updateProgress(1.0)
        story = updatedStory
        
        do {
            try await dataService.saveStory(story)
            let unlocked = await dataService.recordStoryCompleted(
                storyId: story.id.uuidString,
                difficultyLevel: story.difficultyLevel
            )
            if unlocked {
                print("🎉 Level 2 Unlocked!")
            }
        } catch {
            print("Error completing story: \(error)")
        }
    }
    
    func markAsCompleted() async {
        await completeStory()
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
        var updatedStory = story
        updatedStory.resetProgress()
        story = updatedStory
        currentSegmentIndex = 0
        learnedWordIdsInSession.removeAll()
        
        Task {
            try? await dataService.saveStory(story)
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
}
