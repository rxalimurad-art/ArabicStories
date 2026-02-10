//
//  SRSService.swift
//  Hikaya
//  Spaced Repetition System with SM-2 algorithm
//

import Foundation
import SwiftUI
import Combine

@Observable
class SRSService {
    static let shared = SRSService()
    
    private let dataService = DataService.shared
    private let firebaseService = FirebaseService.shared
    
    // Published state
    var dueWords: [Word] = []
    var newWords: [Word] = []
    var reviewWords: [Word] = []
    var isLoading = false
    
    // Daily review session
    var dailyNewWordLimit: Int = 10
    var dailyReviewLimit: Int = 50
    
    private init() {
        Task {
            await loadDueWords()
        }
    }
    
    // MARK: - Load Due Words
    
    func loadDueWords() async {
        isLoading = true
        defer { isLoading = false }
        
        let allWords = await dataService.fetchAllWords()
        let now = Date()
        
        // Separate new words and review words
        newWords = Array(allWords
            .filter { $0.masteryLevel == .new }
            .prefix(dailyNewWordLimit))
        
        reviewWords = Array(allWords
            .filter { word in
                guard word.masteryLevel != .new else { return false }
                guard let nextReview = word.nextReviewDate else { return true }
                return nextReview <= now
            }
            .prefix(dailyReviewLimit))
        
        dueWords = newWords + reviewWords
    }
    
    // MARK: - Review Session
    
    func startReviewSession() async -> [Word] {
        await loadDueWords()
        return dueWords
    }
    
    func processReview(word: Word, response: ResponseQuality) async {
        var updatedWord = word
        updatedWord.processReviewResponse(quality: response)
        
        // Update user progress
        await updateProgress(for: updatedWord, response: response)
        
        // Remove from current session
        dueWords.removeAll { $0.id == word.id }
    }
    
    private func updateProgress(for word: Word, response: ResponseQuality) async {
        guard var progress = await dataService.fetchUserProgress() else { return }
        
        let isNewWord = word.reviewCount == 1
        
        switch response {
        case .again:
            progress.addWeakWord(wordId: word.id.uuidString)
        case .hard:
            progress.recordWordLearned(wordId: word.id.uuidString, isNew: isNewWord)
        case .good, .easy:
            progress.recordWordLearned(wordId: word.id.uuidString, isNew: isNewWord)
            if word.masteryLevel == .mastered {
                progress.recordWordMastered(wordId: word.id.uuidString)
            }
        }
        
        do {
            try await dataService.updateUserProgress(progress)
        } catch {
            print("Error updating progress: \(error)")
        }
    }
    
    // MARK: - Statistics
    
    func getReviewStats() async -> ReviewStats {
        let allWords = await dataService.fetchAllWords()
        
        let total = allWords.count
        let newCount = allWords.filter { $0.masteryLevel == .new }.count
        let learningCount = allWords.filter { $0.masteryLevel == .learning }.count
        let familiarCount = allWords.filter { $0.masteryLevel == .familiar }.count
        let masteredCount = allWords.filter { $0.masteryLevel == .mastered || $0.masteryLevel == .known }.count
        
        let now = Date()
        let dueCount = allWords.filter { word in
            guard let nextReview = word.nextReviewDate else { return word.masteryLevel == .new }
            return nextReview <= now
        }.count
        
        return ReviewStats(
            totalWords: total,
            newWords: newCount,
            learningWords: learningCount,
            familiarWords: familiarCount,
            masteredWords: masteredCount,
            dueToday: dueCount
        )
    }
    
    func getNextReviewDate() async -> Date? {
        let allWords = await dataService.fetchAllWords()
        let futureReviews = allWords.compactMap { $0.nextReviewDate }
        return futureReviews.min()
    }
    
    func getRetentionRate() async -> Double {
        let allWords = await dataService.fetchAllWords()
        guard !allWords.isEmpty else { return 0.0 }
        
        let reviewedWords = allWords.filter { $0.reviewCount > 0 }
        guard !reviewedWords.isEmpty else { return 0.0 }
        
        let successfulReviews = reviewedWords.filter { word in
            word.easeFactor >= 2.5
        }
        
        return Double(successfulReviews.count) / Double(reviewedWords.count)
    }
    
    // MARK: - Settings
    
    func setDailyLimits(newWords: Int, reviews: Int) {
        dailyNewWordLimit = newWords
        dailyReviewLimit = reviews
    }
    
    func resetWordProgress(_ word: Word) {
        var updatedWord = word
        updatedWord.resetSRS()
    }
    
    func suspendWord(_ word: Word) {
        var updatedWord = word
        var components = DateComponents()
        components.day = 30
        updatedWord.nextReviewDate = Calendar.current.date(byAdding: components, to: Date())
    }
}

// MARK: - Review Stats

struct ReviewStats {
    let totalWords: Int
    let newWords: Int
    let learningWords: Int
    let familiarWords: Int
    let masteredWords: Int
    let dueToday: Int
    
    var progressPercentage: Double {
        guard totalWords > 0 else { return 0 }
        return Double(masteredWords) / Double(totalWords)
    }
}

// MARK: - Review Session Manager

class ReviewSessionManager: ObservableObject {
    @Published var currentWord: Word?
    @Published var currentIndex: Int = 0
    @Published var totalCount: Int = 0
    @Published var isFlipped: Bool = false
    @Published var sessionComplete: Bool = false
    @Published var sessionStats: SessionStats = SessionStats()
    
    private var words: [Word] = []
    private let srsService = SRSService.shared
    
    func startSession(with words: [Word]) {
        self.words = words
        self.totalCount = words.count
        self.currentIndex = 0
        self.isFlipped = false
        self.sessionComplete = false
        self.sessionStats = SessionStats()
        
        if !words.isEmpty {
            currentWord = words[0]
        }
    }
    
    func flipCard() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isFlipped.toggle()
        }
    }
    
    func submitReview(_ response: ResponseQuality) async {
        guard let word = currentWord else { return }
        
        await srsService.processReview(word: word, response: response)
        sessionStats.record(response)
        
        // Move to next word
        currentIndex += 1
        isFlipped = false
        
        if currentIndex < words.count {
            currentWord = words[currentIndex]
        } else {
            sessionComplete = true
            currentWord = nil
        }
    }
    
    func skipWord() {
        guard let word = currentWord else { return }
        words.append(word)
        currentIndex += 1
        isFlipped = false
        
        if currentIndex < words.count {
            currentWord = words[currentIndex]
        }
    }
}

struct SessionStats {
    var againCount: Int = 0
    var hardCount: Int = 0
    var goodCount: Int = 0
    var easyCount: Int = 0
    
    var totalReviewed: Int {
        againCount + hardCount + goodCount + easyCount
    }
    
    mutating func record(_ response: ResponseQuality) {
        switch response {
        case .again: againCount += 1
        case .hard: hardCount += 1
        case .good: goodCount += 1
        case .easy: easyCount += 1
        }
    }
    
    var accuracyPercentage: Double {
        guard totalReviewed > 0 else { return 0 }
        let successful = goodCount + easyCount
        return Double(successful) / Double(totalReviewed)
    }
}
