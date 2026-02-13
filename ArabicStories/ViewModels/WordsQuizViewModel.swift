//
//  WordsQuizViewModel.swift
//  Hikaya
//  Combined Words list and Quiz with story-based locking
//

import Foundation
import SwiftUI

@Observable
class WordsQuizViewModel {
    // Dependencies
    private let firebaseService = FirebaseService.shared
    private let dataService = DataService.shared
    
    // MARK: - State
    var allWords: [Word] = []
    var wordStories: [UUID: Story] = [:] // Track which story each word belongs to
    var storyReadStatus: [UUID: Bool] = [:] // Track which stories have been read
    var wordStats: [UUID: WordStat] = [:]
    
    var isLoading = false
    var error: Error?
    
    // Filter & Sort
    var searchQuery: String = ""
    var selectedDifficulty: Int?
    var selectedPartOfSpeech: PartOfSpeech?
    var sortOption: SortOption = .masteryScore
    var sortAscending: Bool = false
    
    // Quiz State
    var isQuizActive = false
    var session: QuizSession?
    var selectedOption: String?
    var showResult = false
    var isCorrect: Bool?
    var startTime: Date?
    var currentStreak = 0
    var bestStreak = 0
    
    enum SortOption: String, CaseIterable {
        case arabic = "Arabic (A-Z)"
        case english = "English (A-Z)"
        case difficulty = "Difficulty"
        case masteryScore = "Mastery Score"
    }
    
    // MARK: - Computed Properties
    
    var filteredWords: [Word] {
        var result = allWords
        
        // Apply search filter
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter { word in
                word.arabicText.lowercased().contains(query) ||
                word.englishMeaning.lowercased().contains(query)
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
            }
            return sortAscending ? !comparison : comparison
        }
        
        return result
    }
    
    var unlockedWords: [Word] {
        filteredWords.filter { isWordUnlocked($0) }
    }
    
    var lockedWords: [Word] {
        filteredWords.filter { !isWordUnlocked($0) }
    }
    
    var quizWords: [Word] {
        unlockedWords.filter { wordStats[$0.id]?.masteryPercentage ?? 0 < 100 }
    }
    
    // MARK: - Quiz Computed Properties
    
    var currentQuestion: QuizQuestion? {
        session?.currentQuestion
    }
    
    var progress: Double {
        session?.progress ?? 0
    }
    
    var totalScore: Int {
        session?.totalScore ?? 0
    }
    
    var isSessionComplete: Bool {
        session?.isCompleted ?? false
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        isLoading = true
        
        do {
            // Load stories with read status
            let stories = try await firebaseService.fetchStories()
            
            // Collect all words and track their stories
            var allWordsList: [Word] = []
            var wordStoryMap: [UUID: Story] = [:]
            
            for story in stories {
                // Check if story has been read (has progress)
                let isRead = story.currentSegmentIndex > 0 || story.readingProgress > 0
                storyReadStatus[story.id] = isRead
                
                if let words = story.words {
                    for word in words {
                        allWordsList.append(word)
                        wordStoryMap[word.id] = story
                    }
                }
            }
            
            // Also load generic words (these are always unlocked)
            let genericWords = try await firebaseService.fetchGenericWords()
            for word in genericWords {
                allWordsList.append(word)
                // Generic words don't have a story, so they're always unlocked
            }
            
            // Remove duplicates
            var uniqueWords: [UUID: Word] = [:]
            for word in allWordsList {
                uniqueWords[word.id] = word
            }
            
            await MainActor.run {
                self.allWords = Array(uniqueWords.values)
                self.wordStories = wordStoryMap
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
        for word in allWords {
            let isUnlocked = isWordUnlocked(word)
            let stat = WordStat(
                wordId: word.id,
                timesReviewed: isUnlocked ? Int.random(in: 0...20) : 0,
                timesCorrect: isUnlocked ? Int.random(in: 0...15) : 0,
                masteryPercentage: isUnlocked ? Int.random(in: 0...100) : 0,
                lastReviewed: isUnlocked ? Date().addingTimeInterval(-Double.random(in: 0...86400*30)) : nil,
                isMastered: isUnlocked ? Bool.random() : false
            )
            wordStats[word.id] = stat
        }
    }
    
    // MARK: - Word Locking
    
    func isWordUnlocked(_ word: Word) -> Bool {
        // If word has no associated story, it's unlocked (generic word)
        guard let story = wordStories[word.id] else {
            return true
        }
        
        // Check if story has been read
        return storyReadStatus[story.id] ?? false
    }
    
    func getLockReason(_ word: Word) -> String? {
        guard let story = wordStories[word.id] else {
            return nil
        }
        
        if !(storyReadStatus[story.id] ?? false) {
            return "Read '\(story.title)' to unlock"
        }
        return nil
    }
    
    // MARK: - Quiz Functions
    
    func startQuiz() async {
        guard !quizWords.isEmpty else { return }
        
        isLoading = true
        
        // Create questions for unlocked words
        var questions: [QuizQuestion] = []
        
        // Take up to 20 words for the quiz
        let wordsForQuiz = Array(quizWords.shuffled().prefix(20))
        
        for word in wordsForQuiz {
            if let question = generateQuestion(for: word) {
                questions.append(question)
            }
        }
        
        await MainActor.run {
            self.session = QuizSession(
                questions: questions.shuffled(),
                masteryThreshold: 20,
                maxQuestionsPerWord: 5
            )
            self.isQuizActive = true
            self.startTime = Date()
            self.isLoading = false
        }
    }
    
    private func generateQuestion(for word: Word) -> QuizQuestion? {
        // Get other words for wrong answers from unlocked words only
        let otherWords = unlockedWords.filter {
            $0.id != word.id &&
            $0.englishMeaning != word.englishMeaning
        }
        
        // Need at least 3 wrong answers for 4 options total
        guard otherWords.count >= 3 else {
            // If not enough words, generate with what we have
            let wrongOptions = otherWords.prefix(3).map { $0.englishMeaning }
            let options = ([word.englishMeaning] + wrongOptions).shuffled()
            
            return QuizQuestion(
                word: word,
                questionType: .arabicToEnglish,
                correctAnswer: word.englishMeaning,
                options: options
            )
        }
        
        // Get 3 wrong answers
        let wrongOptions = otherWords.shuffled().prefix(3).map { $0.englishMeaning }
        let options = ([word.englishMeaning] + wrongOptions).shuffled()
        
        return QuizQuestion(
            word: word,
            questionType: .arabicToEnglish,
            correctAnswer: word.englishMeaning,
            options: options
        )
    }
    
    func selectAnswer(_ answer: String) {
        guard selectedOption == nil, let startTime = startTime else { return }
        
        selectedOption = answer
        let responseTime = Date().timeIntervalSince(startTime)
        
        session?.answerCurrentQuestion(answer, responseTime: responseTime)
        isCorrect = (answer == currentQuestion?.correctAnswer)
        
        if isCorrect == true {
            currentStreak += 1
            if currentStreak > bestStreak {
                bestStreak = currentStreak
            }
        } else {
            currentStreak = 0
        }
        
        showResult = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.nextQuestion()
        }
    }
    
    private func nextQuestion() {
        showResult = false
        selectedOption = nil
        isCorrect = nil
        
        if let session = session, session.currentQuestionIndex >= session.questions.count {
            addQuestionsForUnmasteredWords()
        }
        
        startTime = Date()
    }
    
    private func addQuestionsForUnmasteredWords() {
        guard var session = session else { return }
        
        let unmastered = session.questions
            .map { $0.word }
            .filter { !session.isWordMastered($0.id) }
        
        for word in unmastered {
            if session.questionCount(for: word.id) < session.maxQuestionsPerWord {
                if let newQuestion = generateQuestion(for: word) {
                    session.addQuestion(newQuestion)
                }
            }
        }
        
        self.session = session
    }
    
    func endQuiz() {
        session?.endSession()
        isQuizActive = false
        restartQuiz()
    }
    
    func restartQuiz() {
        session = nil
        selectedOption = nil
        showResult = false
        isCorrect = nil
        currentStreak = 0
        startTime = nil
    }
    
    // MARK: - Filter Actions
    
    func toggleSortDirection() {
        sortAscending.toggle()
    }
    
    func clearFilters() {
        searchQuery = ""
        selectedDifficulty = nil
        selectedPartOfSpeech = nil
        sortOption = .masteryScore
        sortAscending = false
    }
}

// Note: QuizQuestion, QuizSession, and WordStat are defined in Models/WordQuiz.swift
