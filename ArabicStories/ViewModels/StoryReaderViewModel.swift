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
    
    func handleWordTap(word: Word, position: CGPoint) {
        selectedWord = word
        popoverPosition = position
        showWordPopover = true
        
        // Mark word as learned
        var updatedStory = story
        updatedStory.markWordAsLearned(word.id.uuidString)
        story = updatedStory
        
        Task {
            try? await dataService.saveStory(story)
        }
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
}
