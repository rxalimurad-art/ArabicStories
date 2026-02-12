//
//  WordsListViewModel.swift
//  Hikaya
//  ViewModel for words list with scoring and filtering
//

import Foundation
import SwiftUI

@Observable
class WordsListViewModel {
    // Dependencies
    private let firebaseService = FirebaseService.shared
    
    // State
    var words: [Word] = []
    var wordStats: [UUID: WordStat] = [:]
    var isLoading = false
    var error: Error?
    
    // Filter & Sort
    var searchQuery: String = ""
    var selectedDifficulty: Int?
    var selectedPartOfSpeech: PartOfSpeech?
    var selectedCategory: String?
    var sortOption: SortOption = .masteryScore
    var sortAscending: Bool = false
    
    // Categories from generic words
    var availableCategories: [String] = ["general", "noun", "verb", "adjective", "adverb", "phrase", "greeting", "number", "time", "food", "travel", "business"]
    
    enum SortOption: String, CaseIterable {
        case arabic = "Arabic (A-Z)"
        case english = "English (A-Z)"
        case difficulty = "Difficulty"
        case masteryScore = "Mastery Score"
        case timesReviewed = "Times Reviewed"
        case lastReviewed = "Last Reviewed"
    }
    
    // MARK: - Computed Properties
    
    var filteredAndSortedWords: [Word] {
        var result = words
        
        // Apply search filter
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter { word in
                word.arabicText.lowercased().contains(query) ||
                word.englishMeaning.lowercased().contains(query) ||
                word.transliteration?.lowercased().contains(query) == true
            }
        }
        
        // Apply difficulty filter
        if let difficulty = selectedDifficulty {
            result = result.filter { $0.difficulty == difficulty }
        }
        
        // Apply part of speech filter
        if let pos = selectedPartOfSpeech {
            result = result.filter { $0.partOfSpeech == pos }
        }
        
        // Apply category filter
        if let category = selectedCategory {
            result = result.filter { word in
                // Check if word has category in tags or we need to fetch from generic words
                // For now, filter by checking if we can derive category from partOfSpeech
                if let wordPos = word.partOfSpeech?.rawValue,
                   wordPos == category.lowercased() {
                    return true
                }
                return false
            }
        }
        
        // Apply sorting
        result.sort { word1, word2 in
            let comparison: Bool
            switch sortOption {
            case .arabic:
                comparison = word1.arabicText < word2.arabicText
            case .english:
                comparison = word1.englishMeaning < word2.englishMeaning
            case .difficulty:
                comparison = word1.difficulty < word2.difficulty
            case .masteryScore:
                let score1 = wordStats[word1.id]?.masteryPercentage ?? 0
                let score2 = wordStats[word2.id]?.masteryPercentage ?? 0
                comparison = score1 < score2
            case .timesReviewed:
                let count1 = wordStats[word1.id]?.timesReviewed ?? 0
                let count2 = wordStats[word2.id]?.timesReviewed ?? 0
                comparison = count1 < count2
            case .lastReviewed:
                let date1 = wordStats[word1.id]?.lastReviewed ?? Date.distantPast
                let date2 = wordStats[word2.id]?.lastReviewed ?? Date.distantPast
                comparison = date1 < date2
            }
            return sortAscending ? !comparison : comparison
        }
        
        return result
    }
    
    var masteredCount: Int {
        wordStats.values.filter { $0.isMastered }.count
    }
    
    var totalWords: Int {
        words.count
    }
    
    var averageMastery: Double {
        guard !wordStats.isEmpty else { return 0 }
        let total = wordStats.values.reduce(0) { $0 + $1.masteryPercentage }
        return Double(total) / Double(wordStats.count)
    }
    
    // MARK: - Data Loading
    
    func loadWords() async {
        isLoading = true
        
        do {
            // Load generic words from Firebase
            let genericWords = try await firebaseService.fetchGenericWords()
            
            // Also get words from stories
            let stories = try await firebaseService.fetchStories()
            var storyWords: [Word] = []
            for story in stories {
                if let words = story.words {
                    storyWords.append(contentsOf: words)
                }
            }
            
            // Combine and remove duplicates
            var uniqueWords: [UUID: Word] = [:]
            for word in genericWords + storyWords {
                uniqueWords[word.id] = word
            }
            
            await MainActor.run {
                self.words = Array(uniqueWords.values)
                // Load user stats for these words (mock for now)
                self.loadMockStats()
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    private func loadMockStats() {
        // In a real app, these would come from user progress data
        // For now, generate some mock stats
        for word in words {
            let stat = WordStat(
                wordId: word.id,
                timesReviewed: Int.random(in: 0...20),
                timesCorrect: Int.random(in: 0...15),
                masteryPercentage: Int.random(in: 0...100),
                lastReviewed: Bool.random() ? Date().addingTimeInterval(-Double.random(in: 0...86400*30)) : nil,
                isMastered: Bool.random()
            )
            wordStats[word.id] = stat
        }
    }
    
    // MARK: - Actions
    
    func toggleSortDirection() {
        sortAscending.toggle()
    }
    
    func clearFilters() {
        searchQuery = ""
        selectedDifficulty = nil
        selectedPartOfSpeech = nil
        selectedCategory = nil
        sortOption = .masteryScore
        sortAscending = false
    }
}

// MARK: - Word Stat

struct WordStat: Identifiable {
    let id = UUID()
    let wordId: UUID
    var timesReviewed: Int
    var timesCorrect: Int
    var masteryPercentage: Int // 0-100
    var lastReviewed: Date?
    var isMastered: Bool
}
