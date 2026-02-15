//
//  WordQuiz.swift
//  Arabicly
//  Word quiz model with scoring and spaced repetition
//

import Foundation

// MARK: - Quiz Types

enum QuizQuestionType: String, Codable, CaseIterable {
    case arabicToEnglish = "arabic_to_english"    // Show Arabic, select English
    case englishToArabic = "english_to_arabic"    // Show English, select Arabic
    case audioToText = "audio_to_text"            // Play audio, select meaning
}

// MARK: - Quiz Question

struct QuizQuestion: Identifiable, Codable {
    let id: UUID
    let word: Word
    let questionType: QuizQuestionType
    let correctAnswer: String
    let options: [String]                  // Multiple choice options
    let askedAt: Date
    var answeredAt: Date?
    var selectedAnswer: String?
    var isCorrect: Bool?
    var score: Int                          // Points earned/lost
    var responseTime: TimeInterval?         // How long user took to answer
    
    init(id: UUID = UUID(),
         word: Word,
         questionType: QuizQuestionType,
         correctAnswer: String,
         options: [String],
         askedAt: Date = Date()) {
        self.id = id
        self.word = word
        self.questionType = questionType
        self.correctAnswer = correctAnswer
        self.options = options
        self.askedAt = askedAt
        self.score = 0
    }
    
    mutating func answer(_ answer: String, responseTime: TimeInterval) {
        self.selectedAnswer = answer
        self.answeredAt = Date()
        self.responseTime = responseTime
        self.isCorrect = answer == correctAnswer
        
        // Score calculation: +10 for correct, -5 for wrong
        // Bonus: +5 for fast answer (< 3 seconds)
        if self.isCorrect == true {
            var points = 10
            if responseTime < 3.0 {
                points += 5
            }
            self.score = points
        } else {
            self.score = -5
        }
    }
}

// MARK: - Quiz Session

struct QuizSession: Identifiable, Codable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date?
    var questions: [QuizQuestion]
    var totalScore: Int
    var currentQuestionIndex: Int
    var isCompleted: Bool
    
    // Threshold settings
    let masteryThreshold: Int               // Score needed to "master" a word
    let maxQuestionsPerWord: Int           // How many times to ask same word
    
    init(id: UUID = UUID(),
         questions: [QuizQuestion] = [],
         masteryThreshold: Int = 20,
         maxQuestionsPerWord: Int = 5) {
        self.id = id
        self.startedAt = Date()
        self.questions = questions
        self.totalScore = 0
        self.currentQuestionIndex = 0
        self.isCompleted = false
        self.masteryThreshold = masteryThreshold
        self.maxQuestionsPerWord = maxQuestionsPerWord
    }
    
    var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }
    
    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentQuestionIndex) / Double(questions.count)
    }
    
    var correctCount: Int {
        questions.filter { $0.isCorrect == true }.count
    }
    
    var wrongCount: Int {
        questions.filter { $0.isCorrect == false }.count
    }
    
    var accuracy: Double {
        let answered = questions.filter { $0.isCorrect != nil }.count
        guard answered > 0 else { return 0 }
        return Double(correctCount) / Double(answered)
    }
    
    /// Check if a word has been mastered (reached threshold)
    func wordScore(for wordId: UUID) -> Int {
        return questions
            .filter { $0.word.id == wordId && $0.isCorrect != nil }
            .reduce(0) { $0 + $1.score }
    }
    
    func isWordMastered(_ wordId: UUID) -> Bool {
        // Only mastered when 100% progress (100 points)
        wordScore(for: wordId) >= 100
    }
    
    func questionCount(for wordId: UUID) -> Int {
        return questions.filter { $0.word.id == wordId }.count
    }
    
    mutating func addQuestion(_ question: QuizQuestion) {
        questions.append(question)
    }
    
    mutating func answerCurrentQuestion(_ answer: String, responseTime: TimeInterval) {
        guard currentQuestionIndex < questions.count else { return }
        
        questions[currentQuestionIndex].answer(answer, responseTime: responseTime)
        totalScore += questions[currentQuestionIndex].score
        
        // Move to next or end
        currentQuestionIndex += 1
        
        // Check if all words are mastered
        let uniqueWordIds = Set(questions.map { $0.word.id })
        let allMastered = uniqueWordIds.allSatisfy { isWordMastered($0) }
        
        if allMastered || currentQuestionIndex >= questions.count {
            isCompleted = true
            endedAt = Date()
        }
    }
    
    mutating func endSession() {
        isCompleted = true
        endedAt = Date()
    }
}

// MARK: - Word Mastery Tracking

struct WordMastery: Identifiable, Codable {
    let id: UUID                    // Word ID
    var totalScore: Int
    var correctStreak: Int          // Consecutive correct answers
    var wrongStreak: Int            // Consecutive wrong answers
    var timesAsked: Int
    var timesCorrect: Int
    var timesWrong: Int
    var lastAskedAt: Date?
    var masteredAt: Date?
    var isMastered: Bool
    
    var accuracy: Double {
        guard timesAsked > 0 else { return 0 }
        return Double(timesCorrect) / Double(timesAsked)
    }
    
    mutating func update(with question: QuizQuestion) {
        guard let isCorrect = question.isCorrect else { return }
        
        timesAsked += 1
        totalScore += question.score
        lastAskedAt = Date()
        
        if isCorrect {
            timesCorrect += 1
            correctStreak += 1
            wrongStreak = 0
        } else {
            timesWrong += 1
            wrongStreak += 1
            correctStreak = 0
        }
        
        // Mark as mastered only when 100% progress reached
        // Progress = min(totalScore / 100, 1.0)
        let progress = min(Double(totalScore) / 100.0, 1.0)
        if progress >= 1.0 && !isMastered {
            isMastered = true
            masteredAt = Date()
        }
    }
}

// MARK: - Quiz Settings

struct QuizSettings: Codable {
    var questionTypes: [QuizQuestionType]
    var optionsCount: Int               // How many choices (3-6)
    var masteryThreshold: Int          // Score needed to master
    var maxQuestionsPerSession: Int    // Limit session length
    var includeGenericWords: Bool      // Use generic word bank
    var includeStoryWords: Bool        // Use story words
    var difficultyLevels: [Int]        // Which difficulty levels to include
    
    static let `default` = QuizSettings(
        questionTypes: [.arabicToEnglish, .englishToArabic],
        optionsCount: 4,
        masteryThreshold: 20,
        maxQuestionsPerSession: 50,
        includeGenericWords: true,
        includeStoryWords: true,
        difficultyLevels: [1, 2, 3, 4, 5]
    )
}
