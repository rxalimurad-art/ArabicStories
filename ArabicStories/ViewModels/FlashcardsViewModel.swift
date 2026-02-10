//
//  FlashcardsViewModel.swift
//  Hikaya
//  ViewModel for Flashcards and SRS review sessions
//

import Foundation
import SwiftUI

@Observable
class FlashcardsViewModel {
    // Dependencies
    private let srsService = SRSService.shared
    private let dataService = DataService.shared
    
    // State
    var dueWords: [Word] = []
    var newWords: [Word] = []
    var reviewWords: [Word] = []
    var allWords: [Word] = []
    var isLoading = false
    
    // Review Session State
    var isReviewSessionActive = false
    var currentWord: Word?
    var currentIndex = 0
    var totalCount = 0
    var isFlipped = false
    var sessionComplete = false
    
    // Session Stats
    var againCount = 0
    var hardCount = 0
    var goodCount = 0
    var easyCount = 0
    
    // Settings
    var dailyNewWordLimit = 10
    var dailyReviewLimit = 50
    var autoPlayAudio = true
    
    // Statistics
    var reviewStats: ReviewStats?
    
    init() {
        Task {
            await loadData()
        }
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        await loadDueWords()
        await loadAllWords()
        await loadStatistics()
    }
    
    func loadDueWords() async {
        dueWords = await srsService.dueWords
        newWords = await srsService.newWords
        reviewWords = await srsService.reviewWords
    }
    
    func loadAllWords() async {
        allWords = await dataService.fetchAllWords()
    }
    
    func loadStatistics() async {
        reviewStats = await srsService.getReviewStats()
    }
    
    func refresh() async {
        await loadData()
    }
    
    // MARK: - Review Session
    
    func startReviewSession() async {
        let words = await srsService.startReviewSession()
        guard !words.isEmpty else { return }
        
        dueWords = words
        currentIndex = 0
        totalCount = words.count
        isFlipped = false
        sessionComplete = false
        againCount = 0
        hardCount = 0
        goodCount = 0
        easyCount = 0
        
        currentWord = words.first
        isReviewSessionActive = true
    }
    
    func flipCard() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isFlipped.toggle()
        }
    }
    
    func submitReview(_ response: ResponseQuality) async {
        guard let word = currentWord else { return }
        
        // Update stats
        switch response {
        case .again: againCount += 1
        case .hard: hardCount += 1
        case .good: goodCount += 1
        case .easy: easyCount += 1
        }
        
        // Process in SRS service
        await srsService.processReview(word: word, response: response)
        
        // Move to next word
        currentIndex += 1
        isFlipped = false
        
        if currentIndex < dueWords.count {
            currentWord = dueWords[currentIndex]
        } else {
            sessionComplete = true
            currentWord = nil
            isReviewSessionActive = false
            
            // Refresh statistics
            await loadStatistics()
        }
    }
    
    func skipWord() {
        // Move current word to end
        guard let word = currentWord else { return }
        dueWords.append(word)
        currentIndex += 1
        isFlipped = false
        
        if currentIndex < dueWords.count {
            currentWord = dueWords[currentIndex]
        }
    }
    
    func endSession() {
        isReviewSessionActive = false
        currentWord = nil
        sessionComplete = false
    }
    
    // MARK: - Word Management
    
    func toggleBookmark(_ word: Word) {
        dataService.toggleWordBookmark(word)
        
        // Update local state
        if let index = allWords.firstIndex(where: { $0.id == word.id }) {
            allWords[index] = word
        }
    }
    
    func resetWordProgress(_ word: Word) {
        srsService.resetWordProgress(word)
    }
    
    func suspendWord(_ word: Word) {
        srsService.suspendWord(word)
    }
    
    func deleteWord(_ word: Word) async {
        // Implementation for deleting user-created words
    }
    
    // MARK: - Settings
    
    func updateDailyLimits(newWords: Int, reviews: Int) {
        dailyNewWordLimit = newWords
        dailyReviewLimit = reviews
        srsService.setDailyLimits(newWords: newWords, reviews: reviews)
    }
    
    // MARK: - Computed Properties
    
    var sessionProgress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(currentIndex) / Double(totalCount)
    }
    
    var accuracyRate: Double {
        let totalReviewed = againCount + hardCount + goodCount + easyCount
        guard totalReviewed > 0 else { return 0 }
        let successful = goodCount + easyCount
        return Double(successful) / Double(totalReviewed)
    }
    
    var bookmarkedWords: [Word] {
        allWords.filter { $0.isBookmarked }
    }
    
    var wordsByMastery: [MasteryLevel: [Word]] {
        Dictionary(grouping: allWords) { $0.masteryLevel }
    }
    
    var dueTodayCount: Int {
        dueWords.count
    }
    
    var isDailyReviewComplete: Bool {
        dueWords.isEmpty
    }
    
    var nextReviewDate: Date? {
        // Calculate next review date based on due words
        let futureReviews = allWords.compactMap { $0.nextReviewDate }
        return futureReviews.min()
    }
    
    var totalSessionCards: Int {
        againCount + hardCount + goodCount + easyCount
    }
}
