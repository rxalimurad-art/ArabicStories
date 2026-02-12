//
//  WordQuizViewModel.swift
//  Arabicly
//  ViewModel for word quiz with adaptive learning
//

import Foundation
import SwiftUI

@Observable
class WordQuizViewModel {
    // MARK: - Dependencies
    private let firebaseService = FirebaseService.shared
    private let dataService = DataService.shared
    
    // MARK: - State
    var session: QuizSession?
    var settings: QuizSettings = .default
    
    // Current question state
    var selectedOption: String?
    var showResult = false
    var isCorrect: Bool?
    var startTime: Date?
    
    // Overall state
    var availableWords: [Word] = []
    var wordMastery: [UUID: WordMastery] = [:]
    var isLoading = false
    var error: Error?
    
    // Stats
    var currentStreak = 0
    var bestStreak = 0
    
    // MARK: - Computed Properties
    
    var currentQuestion: QuizQuestion? {
        session?.currentQuestion
    }
    
    var currentWord: Word? {
        currentQuestion?.word
    }
    
    var progress: Double {
        session?.progress ?? 0
    }
    
    var totalScore: Int {
        session?.totalScore ?? 0
    }
    
    var questionsAnswered: Int {
        session?.currentQuestionIndex ?? 0
    }
    
    var isSessionComplete: Bool {
        session?.isCompleted ?? false
    }
    
    // MARK: - Session Management
    
    func startQuiz(withWords words: [Word]? = nil, settings: QuizSettings = .default) async {
        self.settings = settings
        isLoading = true
        
        do {
            // Get words to quiz
            var quizWords: [Word]
            if let providedWords = words, !providedWords.isEmpty {
                quizWords = providedWords
            } else {
                quizWords = try await loadWordsForQuiz()
            }
            
            // Filter by difficulty if set
            if !settings.difficultyLevels.isEmpty {
                quizWords = quizWords.filter { settings.difficultyLevels.contains($0.difficulty) }
            }
            
            // Take max words for session
            if quizWords.count > settings.maxQuestionsPerSession {
                quizWords = Array(quizWords.shuffled().prefix(settings.maxQuestionsPerSession))
            }
            
            guard !quizWords.isEmpty else {
                throw QuizError.noWordsAvailable
            }
            
            // Create initial questions
            var questions: [QuizQuestion] = []
            for word in quizWords {
                if let question = generateQuestion(for: word) {
                    questions.append(question)
                }
            }
            
            // Create session
            await MainActor.run {
                self.session = QuizSession(
                    questions: questions.shuffled(),
                    masteryThreshold: settings.masteryThreshold,
                    maxQuestionsPerWord: 5
                )
                self.startTime = Date()
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    func loadWordsForQuiz() async throws -> [Word] {
        var words: [Word] = []
        
        if settings.includeGenericWords {
            let genericWords = try await firebaseService.fetchGenericWords()
            words.append(contentsOf: genericWords)
        }
        
        if settings.includeStoryWords {
            let stories = try await firebaseService.fetchStories()
            for story in stories {
                if let storyWords = story.words {
                    words.append(contentsOf: storyWords)
                }
            }
        }
        
        // Remove duplicates by Arabic text
        var seenArabic: Set<String> = []
        words = words.filter { word in
            let normalized = ArabicTextUtils.normalizeForMatching(word.arabicText)
            if seenArabic.contains(normalized) {
                return false
            }
            seenArabic.insert(normalized)
            return true
        }
        
        return words
    }
    
    // MARK: - Question Generation
    
    private func generateQuestion(for word: Word) -> QuizQuestion? {
        let questionType = settings.questionTypes.randomElement() ?? .arabicToEnglish
        
        switch questionType {
        case .arabicToEnglish:
            return generateArabicToEnglishQuestion(for: word)
        case .englishToArabic:
            return generateEnglishToArabicQuestion(for: word)
        case .audioToText:
            // TODO: Implement when audio is available
            return generateArabicToEnglishQuestion(for: word)
        }
    }
    
    private func generateArabicToEnglishQuestion(for word: Word) -> QuizQuestion? {
        // Get other words for wrong answers
        let otherWords = availableWords.filter { 
            $0.id != word.id && 
            ArabicTextUtils.normalizeForMatching($0.englishMeaning) != 
            ArabicTextUtils.normalizeForMatching(word.englishMeaning)
        }
        
        let wrongOptions = otherWords.shuffled().prefix(settings.optionsCount - 1).map { $0.englishMeaning }
        let options = ([word.englishMeaning] + wrongOptions).shuffled()
        
        return QuizQuestion(
            word: word,
            questionType: .arabicToEnglish,
            correctAnswer: word.englishMeaning,
            options: options
        )
    }
    
    private func generateEnglishToArabicQuestion(for word: Word) -> QuizQuestion? {
        let otherWords = availableWords.filter { 
            $0.id != word.id &&
            ArabicTextUtils.normalizeForMatching($0.arabicText) !=
            ArabicTextUtils.normalizeForMatching(word.arabicText)
        }
        
        let wrongOptions = otherWords.shuffled().prefix(settings.optionsCount - 1).map { $0.arabicText }
        let options = ([word.arabicText] + wrongOptions).shuffled()
        
        return QuizQuestion(
            word: word,
            questionType: .englishToArabic,
            correctAnswer: word.arabicText,
            options: options
        )
    }
    
    // MARK: - Answering
    
    func selectAnswer(_ answer: String) {
        guard selectedOption == nil, let startTime = startTime else { return }
        
        selectedOption = answer
        let responseTime = Date().timeIntervalSince(startTime)
        
        // Record answer
        session?.answerCurrentQuestion(answer, responseTime: responseTime)
        
        // Check if correct
        isCorrect = (answer == currentQuestion?.correctAnswer)
        
        // Update streaks
        if isCorrect == true {
            currentStreak += 1
            if currentStreak > bestStreak {
                bestStreak = currentStreak
            }
        } else {
            currentStreak = 0
        }
        
        // Update word mastery tracking
        if let question = currentQuestion {
            updateMastery(for: question)
        }
        
        showResult = true
        
        // Auto-advance after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.nextQuestion()
        }
    }
    
    private func updateMastery(for question: QuizQuestion) {
        let wordId = question.word.id
        
        if var mastery = wordMastery[wordId] {
            mastery.update(with: question)
            wordMastery[wordId] = mastery
        } else {
            var newMastery = WordMastery(
                id: wordId,
                totalScore: 0,
                correctStreak: 0,
                wrongStreak: 0,
                timesAsked: 0,
                timesCorrect: 0,
                timesWrong: 0,
                isMastered: false
            )
            newMastery.update(with: question)
            wordMastery[wordId] = newMastery
        }
    }
    
    private func nextQuestion() {
        showResult = false
        selectedOption = nil
        isCorrect = nil
        
        // Check if we need to add more questions for unmastered words
        if let session = session, session.currentQuestionIndex >= session.questions.count {
            // Session ended naturally - add more questions for unmastered words
            addQuestionsForUnmasteredWords()
        }
        
        startTime = Date()
    }
    
    private func addQuestionsForUnmasteredWords() {
        guard var session = session else { return }
        
        let unmasteredWords = session.questions
            .map { $0.word }
            .filter { !session.isWordMastered($0.id) }
        
        for word in unmasteredWords {
            // Only add more if under max limit
            if session.questionCount(for: word.id) < session.maxQuestionsPerWord {
                if let newQuestion = generateQuestion(for: word) {
                    session.addQuestion(newQuestion)
                }
            }
        }
        
        self.session = session
    }
    
    func endSession() {
        session?.endSession()
        
        // Save progress
        Task {
            await saveProgress()
        }
    }
    
    private func saveProgress() async {
        // Save word mastery data to user progress
        // Implementation depends on your data service
    }
    
    func restartQuiz() {
        session = nil
        selectedOption = nil
        showResult = false
        isCorrect = nil
        currentStreak = 0
        wordMastery = [:]
        startTime = nil
    }
    
    // MARK: - Results
    
    func getResults() -> QuizResults? {
        guard let session = session else { return nil }
        
        return QuizResults(
            totalScore: session.totalScore,
            correctCount: session.correctCount,
            wrongCount: session.wrongCount,
            accuracy: session.accuracy,
            masteredWords: Array(wordMastery.values.filter { $0.isMastered }),
            unmasteredWords: Array(wordMastery.values.filter { !$0.isMastered }),
            sessionDuration: session.endedAt?.timeIntervalSince(session.startedAt) ?? 0,
            bestStreak: bestStreak
        )
    }
}

// MARK: - Supporting Types

struct QuizResults {
    let totalScore: Int
    let correctCount: Int
    let wrongCount: Int
    let accuracy: Double
    let masteredWords: [WordMastery]
    let unmasteredWords: [WordMastery]
    let sessionDuration: TimeInterval
    let bestStreak: Int
}

enum QuizError: Error, LocalizedError {
    case noWordsAvailable
    case sessionNotStarted
    
    var errorDescription: String? {
        switch self {
        case .noWordsAvailable:
            return "No words available for quiz. Please add some words first."
        case .sessionNotStarted:
            return "Quiz session hasn't started yet."
        }
    }
}
