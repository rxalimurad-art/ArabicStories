//
//  StoryProgress.swift
//  Arabicly
//  User-specific story progress tracking
//

import Foundation

/// User-specific progress for a story - stored per user
struct StoryProgress: Identifiable, Codable {
    var id: String { storyId }
    let storyId: String
    let userId: String
    
    // Progress tracking
    var readingProgress: Double
    var currentSegmentIndex: Int
    var lastReadDate: Date?
    var completedWords: [String: Bool]
    var learnedWordIds: [String]
    var isBookmarked: Bool
    var totalReadingTime: TimeInterval
    
    // Completion tracking
    var isCompleted: Bool
    var completionDate: Date?
    
    // Timestamps
    var startedAt: Date
    var updatedAt: Date
    
    init(storyId: String, userId: String) {
        self.storyId = storyId
        self.userId = userId
        self.readingProgress = 0.0
        self.currentSegmentIndex = 0
        self.completedWords = [:]
        self.learnedWordIds = []
        self.isBookmarked = false
        self.totalReadingTime = 0
        self.isCompleted = false
        self.startedAt = Date()
        self.updatedAt = Date()
    }
    
    mutating func updateProgress(_ progress: Double) {
        readingProgress = min(max(progress, 0.0), 1.0)
        lastReadDate = Date()
        updatedAt = Date()
        
        if readingProgress >= 1.0 && !isCompleted {
            isCompleted = true
            completionDate = Date()
        }
    }
    
    mutating func updateSegmentIndex(_ index: Int) {
        currentSegmentIndex = index
        lastReadDate = Date()
        updatedAt = Date()
    }
    
    mutating func markWordAsLearned(_ wordId: String) {
        if !learnedWordIds.contains(wordId) {
            learnedWordIds.append(wordId)
        }
        updatedAt = Date()
    }
    
    mutating func markWordAsCompleted(_ wordId: String, completed: Bool = true) {
        completedWords[wordId] = completed
        updatedAt = Date()
    }
    
    mutating func addReadingTime(_ time: TimeInterval) {
        totalReadingTime += time
        updatedAt = Date()
    }
    
    mutating func toggleBookmark() {
        isBookmarked.toggle()
        updatedAt = Date()
    }
    
    mutating func reset() {
        readingProgress = 0.0
        currentSegmentIndex = 0
        completedWords = [:]
        learnedWordIds = []
        isBookmarked = false
        totalReadingTime = 0
        isCompleted = false
        completionDate = nil
        updatedAt = Date()
    }
}

// MARK: - Helper Extensions

extension StoryProgress {
    var isInProgress: Bool {
        readingProgress > 0.0 && readingProgress < 1.0
    }
    
    var isNew: Bool {
        readingProgress == 0.0
    }
    
    var learnedVocabularyCount: Int {
        learnedWordIds.count
    }
}
