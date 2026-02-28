//
//  MyWordsViewModel.swift
//  Arabicly
//  ViewModel for My Words (Quran words with learning progress)
//

import Foundation
import SwiftUI
import FirebaseAuth

@Observable
class MyWordsViewModel {
    // Dependencies
    private let dataService = DataService.shared
    private let firebaseService = FirebaseService.shared
    private let networkMonitor = NetworkMonitor.shared
    
    // MARK: - State
    var unlockedWords: [QuranWord] = [] { didSet { updateCachedSortedWords() } }
    var isLoading = false
    var error: Error?
    var errorMessage: String?
    var showErrorAlert = false
    var sortOption: WordSortOption = .score { didSet { updateCachedSortedWords() } }
    var filterOption: WordFilterOption = .all { didSet { updateCachedSortedWords() } }
    
    // Quiz State
    var isQuizActive = false
    var session: QuizSession?
    var selectedOption: String?
    var showResult = false
    var isCorrect: Bool?
    var startTime: Date?
    var currentStreak = 0
    var bestStreak = 0
    var lastScore = 0  // Score from last answer for feedback

    // Pending answer (deferred so session doesn't advance while showing result)
    private var pendingAnswer: String?
    private var pendingResponseTime: TimeInterval = 0
    
    // Word Mastery Tracking
    var wordMastery: [String: WordMastery] = [:]
    
    // MARK: - Cached Sorted Words

    private(set) var cachedSortedWords: [QuranWord] = []

    private func updateCachedSortedWords() {
        let filtered: [QuranWord]
        switch filterOption {
        case .all:
            filtered = unlockedWords
        case .starred:
            filtered = unlockedWords.filter { $0.isBookmarked == true }
        case .mastered:
            filtered = unlockedWords.filter { $0.isWordMastered }
        case .toReview:
            filtered = unlockedWords.filter { !$0.isWordMastered }
        }

        cachedSortedWords = filtered.sorted { a, b in
            switch sortOption {
            case .score:
                let scoreA = wordMastery[a.id]?.totalScore ?? 0
                let scoreB = wordMastery[b.id]?.totalScore ?? 0
                return scoreA > scoreB
            case .quranFreq:
                return a.occurrenceCount > b.occurrenceCount
            case .alphabetical:
                return a.arabicText.localizedCompare(b.arabicText) == .orderedAscending
            case .rank:
                return a.rank < b.rank
            }
        }
    }

    var masteredWords: [QuranWord] {
        unlockedWords.filter { $0.isWordMastered }
    }
    
    var wordsToReview: [QuranWord] {
        unlockedWords.filter { !$0.isWordMastered }
    }
    
    var quizWords: [QuranWord] {
        wordsToReview.isEmpty ? unlockedWords : wordsToReview
    }
    
    var currentQuestion: QuizQuestion? {
        session?.currentQuestion
    }
    
    var currentQuestionIndex: Int {
        session?.currentQuestionIndex ?? 0
    }
    
    var totalQuestions: Int {
        session?.questions.count ?? 0
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
    
    var correctCount: Int {
        session?.correctCount ?? 0
    }
    
    var wrongCount: Int {
        session?.wrongCount ?? 0
    }
    
    var accuracy: Int {
        guard let session = session else { return 0 }
        let answered = session.questions.filter { $0.isCorrect != nil }.count
        guard answered > 0 else { return 0 }
        return Int(Double(correctCount) / Double(answered) * 100)
    }
    
    // MARK: - Star/Bookmark Words

    func toggleStarWord(wordId: String) {
        if let index = unlockedWords.firstIndex(where: { $0.id == wordId }) {
            let current = unlockedWords[index].isBookmarked ?? false
            unlockedWords[index].isBookmarked = !current

            // Persist to Firebase
            Task {
                await dataService.updateQuranWordBookmark(wordId: wordId, isBookmarked: !current)
            }
        }
    }

    var starredWords: [QuranWord] {
        unlockedWords.filter { $0.isBookmarked == true }
    }

    // MARK: - Word Progress

    func isWordMastered(_ wordId: String) -> Bool {
        wordMastery[wordId]?.isMastered ?? false
    }
    
    func wordProgress(_ wordId: String) -> Double {
        guard let mastery = wordMastery[wordId] else { return 0 }
        // Progress from 0.0 to 1.0 (100% mastery at 100 points)
        return min(Double(mastery.totalScore) / 100.0, 1.0)
    }
    
    // MARK: - Load Unlocked Words
    
    /// Load user's unlocked words from Firebase
    func loadUnlockedWords() async {
        isLoading = true
        print("📚 MyWords: Starting to load unlocked Quran words...")
        print("📚 MyWords: Current user: \(Auth.auth().currentUser?.uid ?? "none")")
        
        do {
            // Fetch from user's learned vocabulary collection
            let learnedWords = await dataService.fetchLearnedQuranWords()
            print("📚 MyWords: Fetched \(learnedWords.count) learned Quran words")
            
            // Load saved mastery data
            let savedMastery = await dataService.fetchWordMastery()
            print("📚 MyWords: Loaded \(savedMastery.count) saved mastery entries")
            
            await MainActor.run {
                // Set wordMastery first so didSet on unlockedWords sees correct scores
                self.wordMastery = savedMastery
                self.unlockedWords = learnedWords  // triggers updateCachedSortedWords via didSet
                // Initialize mastery for new words then refresh cache
                self.initializeMissingMasteryData()
                self.updateCachedSortedWords()
                self.isLoading = false
                print("📚 MyWords: Done! Loaded \(learnedWords.count) words")
            }
            
        } catch {
            print("📚 MyWords: Error loading words: \(error)")
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    /// Initialize mastery data only for words that don't have saved data yet
    private func initializeMissingMasteryData() {
        for word in unlockedWords {
            if wordMastery[word.id] == nil {
                let mastery = WordMastery(
                    id: word.id,
                    totalScore: 0,
                    correctStreak: 0,
                    wrongStreak: 0,
                    timesAsked: 0,
                    timesCorrect: 0,
                    timesWrong: 0,
                    isMastered: false
                )
                wordMastery[word.id] = mastery
            }
        }
    }
    
    // MARK: - Quiz Functions
    
    func startQuiz() async {
        guard !quizWords.isEmpty else { return }
        
        isLoading = true
        
        // Create questions for quiz words
        var questions: [QuizQuestion] = []
        
        // Take up to 20 words for the quiz
        let wordsForQuiz = Array(quizWords.shuffled().prefix(20))
        
        for word in wordsForQuiz {
            if let question = generateQuestion(for: word) {
                questions.append(question)
            }
        }
        
        guard !questions.isEmpty else {
            isLoading = false
            return
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
    
    private func generateQuestion(for word: QuranWord) -> QuizQuestion? {
        // Get other words for wrong answers
        let otherWords = unlockedWords.filter {
            $0.id != word.id &&
            $0.englishMeaning != word.englishMeaning
        }
        
        // Need at least 3 wrong answers for 4 options total
        guard otherWords.count >= 3 else {
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

        guard let question = currentQuestion else { return }

        let correct = (answer == question.correctAnswer)
        isCorrect = correct

        // Store pending answer
        pendingAnswer = answer
        pendingResponseTime = responseTime

        // Compute score for feedback display
        lastScore = correct ? 10 : -20

        // Update word mastery
        updateWordMastery(word: question.word, isCorrect: correct)

        if correct {
            SoundEffectService.shared.playCorrect()
            currentStreak += 1
            if currentStreak > bestStreak {
                bestStreak = currentStreak
            }
        } else {
            SoundEffectService.shared.playWrong()
            currentStreak = 0
        }

        showResult = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.nextQuestion()
        }
    }
    
    /// Update word mastery progress after answering a question
    private func updateWordMastery(word: QuranWord, isCorrect: Bool) {
        var mastery = wordMastery[word.id] ?? WordMastery(
            id: word.id,
            totalScore: 0,
            correctStreak: 0,
            wrongStreak: 0,
            timesAsked: 0,
            timesCorrect: 0,
            timesWrong: 0,
            isMastered: false
        )

        mastery.timesAsked += 1

        if isCorrect {
            mastery.totalScore += 10
            mastery.timesCorrect += 1
            mastery.correctStreak += 1
            mastery.wrongStreak = 0
        } else {
            mastery.totalScore = max(0, mastery.totalScore - 20)
            mastery.timesWrong += 1
            mastery.wrongStreak += 1
            mastery.correctStreak = 0
        }

        // Check if word is mastered (score >= 100)
        mastery.isMastered = mastery.totalScore >= 100

        wordMastery[word.id] = mastery

        // Update the word in unlockedWords
        if let index = unlockedWords.firstIndex(where: { $0.id == word.id }) {
            unlockedWords[index].mastery = min(Double(mastery.totalScore) / 100.0, 1.0)
            unlockedWords[index].isMastered = mastery.isMastered
            unlockedWords[index].reviewCount = mastery.timesAsked
        }

        print("📚 Word '\(word.arabicText)' mastery updated: score=\(mastery.totalScore), mastered=\(mastery.isMastered)")
    }
    
    private func nextQuestion() {
        // Advance the session
        if let answer = pendingAnswer {
            session?.answerCurrentQuestion(answer, responseTime: pendingResponseTime)
            pendingAnswer = nil
            pendingResponseTime = 0
        }

        // Reset UI state
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
    
    func endQuiz() async {
        session?.endSession()
        isQuizActive = false
        
        // Save mastery data
        print("💾 Saving word mastery: \(wordMastery.count) entries")
        await dataService.saveWordMastery(wordMastery)
        
        // Save updated word progress
        await dataService.saveLearnedQuranWords(unlockedWords)
        
        print("💾 Word mastery save completed")
        
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
}

// MARK: - Sort & Filter Enums

enum WordSortOption: String, CaseIterable {
    case score = "Score"
    case quranFreq = "Quran Freq"
    case alphabetical = "A-Z"
    case rank = "Rank"

    var icon: String {
        switch self {
        case .score: return "star.fill"
        case .quranFreq: return "book.fill"
        case .alphabetical: return "textformat.abc"
        case .rank: return "number"
        }
    }
}

enum WordFilterOption: String, CaseIterable {
    case all = "All"
    case starred = "Starred"
    case mastered = "Mastered"
    case toReview = "To Review"
}
