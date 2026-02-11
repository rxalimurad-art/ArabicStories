//
//  StoryReaderViewModel.swift
//  Hikaya
//  ViewModel for the Story Reader with audio sync
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
    
    // Settings
    var fontSize: CGFloat = 20
    var isNightMode = false
    var showEnglish = true
    var showTransliteration = true
    var autoScrollEnabled = true
    
    init(story: Story) {
        self.story = story
        self.currentSegmentIndex = story.currentSegmentIndex
        setupAudioCallbacks()
        
        // Debug: Print story info
        print("📖 StoryReaderViewModel initialized")
        print("   Story: '\(story.title)'")
        print("   Segments: \(story.segments?.count ?? 0)")
        print("   Words: \(story.words?.count ?? 0)")
        if let words = story.words {
            for word in words {
                print("   - Word: '\(word.arabicText)' = '\(word.englishMeaning)'")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var currentSegment: StorySegment? {
        guard let segments = story.segments,
              currentSegmentIndex < segments.count else { return nil }
        return segments.sorted { $0.index < $1.index }[currentSegmentIndex]
    }
    
    var totalSegments: Int {
        story.segments?.count ?? 0
    }
    
    var readingProgress: Double {
        guard totalSegments > 0 else { return 0 }
        return Double(currentSegmentIndex) / Double(totalSegments)
    }
    
    var canGoNext: Bool {
        currentSegmentIndex < totalSegments - 1
    }
    
    var canGoPrevious: Bool {
        currentSegmentIndex > 0
    }
    
    // MARK: - Navigation
    
    func goToNextSegment() async {
        guard canGoNext else { return }
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
    
    // MARK: - Word Interaction
    
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
        
        // Find the word in the story's vocabulary first
        let cleanedWord = wordText.trimmingCharacters(in: .punctuationCharacters)
        print("🔍 Looking for match: '\(cleanedWord)'")
        
        if let word = story.words?.first(where: { 
            $0.arabicText == cleanedWord || $0.arabicText.contains(cleanedWord)
        }) {
            print("✅ Found word match in story: '\(word.arabicText)' = '\(word.englishMeaning)'")
            showWordDetails(word: word, position: position)
        } else {
            print("❌ No word match found in story for '\(cleanedWord)'")
            print("🔍 Searching in generic words collection...")
            
            // Search in generic words
            Task {
                await searchGenericWords(cleanedWord, position: position)
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
                    
                    // Create a placeholder word for unknown words
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
        popoverPosition = position
        showWordPopover = true
        
        // Mark word as learned (only if it's from story or known generic word)
        if word.englishMeaning != "Unknown word" {
            var updatedStory = story
            updatedStory.markWordAsLearned(word.id.uuidString)
            story = updatedStory
            
            Task {
                try? await dataService.saveStory(story)
            }
        }
    }
    
    func isWordLearned(_ wordId: String) -> Bool {
        story.isWordLearned(wordId)
    }
    
    func toggleWordBookmark(_ word: Word) {
        // Implementation for bookmarking word - would need to be saved to user progress
        // For now, just a placeholder
    }
    
    func addWordToFlashcards(_ word: Word) {
        // Implementation for adding word to flashcards
        // Would add to a flashcard list in user progress
    }
    
    func playWordPronunciation(_ word: Word) {
        Task {
            await pronunciationService.playPronunciation(for: word)
        }
    }
    
    func closeWordPopover() {
        showWordPopover = false
        selectedWord = nil
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
    
    func markAsCompleted() async {
        var updatedStory = story
        updatedStory.updateProgress(1.0)
        story = updatedStory
        
        do {
            try await dataService.saveStory(story)
        } catch {
            print("Error marking complete: \(error)")
        }
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
}
