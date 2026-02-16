//
//  MyWordsViewModel.swift
//  Arabicly
//  ViewModel for My Words (unlocked words from stories with quiz)
//

import Foundation
import SwiftUI
import FirebaseAuth

@Observable
class MyWordsViewModel {
    // Dependencies
    private let dataService = DataService.shared
    private let firebaseService = FirebaseService.shared
    
    // MARK: - State
    var unlockedWords: [Word] = []
    var isLoading = false
    var error: Error?
    
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
    
    // Word Mastery Tracking
    var wordMastery: [UUID: WordMastery] = [:]
    
    // MARK: - Computed Properties
    
    var masteredWords: [Word] {
        unlockedWords.filter { wordMastery[$0.id]?.isMastered == true }
    }
    
    var wordsToReview: [Word] {
        unlockedWords.filter { wordMastery[$0.id]?.isMastered != true }
    }
    
    var quizWords: [Word] {
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
    
    // MARK: - Word Progress
    
    func isWordMastered(_ wordId: UUID) -> Bool {
        wordMastery[wordId]?.isMastered ?? false
    }
    
    func wordProgress(_ wordId: UUID) -> Double {
        guard let mastery = wordMastery[wordId] else { return 0 }
        // Progress from 0.0 to 1.0 (100% mastery at 100 points)
        return min(Double(mastery.totalScore) / 100.0, 1.0)
    }
    
    // MARK: - Load Unlocked Words
    
    func loadUnlockedWords() async {
        isLoading = true
        print("📚 MyWords: Starting to load unlocked Quran words...")
        print("📚 MyWords: Current user: \(Auth.auth().currentUser?.uid ?? "none")")
        
        do {
            // Step 1: Sync story progress from Firebase to local cache
            await dataService.syncAllStoryProgressFromFirebase()
            
            // Step 2: Get all story progress to find completed stories
            let allStoryProgress = await dataService.getAllStoryProgress()
            print("📚 MyWords: Got \(allStoryProgress.count) story progress entries")
            
            // Find completed story IDs from StoryProgress (lowercased for case-insensitive comparison)
            var completedStoryIds = Set(allStoryProgress.filter { 
                $0.isCompleted || $0.readingProgress >= 1.0 
            }.map { $0.storyId.lowercased() })
            
            // Also check UserProgress for completed stories (lowercased for case-insensitive comparison)
            if let userProgress = await dataService.fetchUserProgress() {
                let userCompletedIds = Set(userProgress.completedStoryIds.map { $0.lowercased() })
                completedStoryIds = completedStoryIds.union(userCompletedIds)
            }
            
            print("📚 MyWords: Total unique completed story IDs: \(completedStoryIds)")
            
            // Step 3: Fetch all stories
            let allStories = await dataService.fetchAllStories()
            print("📚 MyWords: Total stories fetched: \(allStories.count)")
            
            // Step 4: Pre-load Quran words for matching
            print("📚 MyWords: Loading Quran words for matching...")
            let quranWordsResult = try await firebaseService.fetchQuranWords(limit: 1000, offset: 0, sort: "rank")
            let quranWords = quranWordsResult.words
            print("📚 MyWords: Loaded \(quranWords.count) Quran words for matching")
            
            // Step 5: Find Quran words in completed stories
            var collectedWords: [Word] = []
            var seenWordIds: Set<UUID> = []
            var completedStoriesCount = 0
            var totalMatchedWords = 0
            
            print("📚 MyWords: Checking \(allStories.count) stories against completed IDs: \(completedStoryIds)")
            
            for story in allStories {
                let storyIdString = story.id.uuidString.lowercased()
                let isCompleted = completedStoryIds.contains(storyIdString)
                
                print("📚 MyWords: Story '\(story.title)' ID: \(storyIdString), completed: \(isCompleted)")
                
                if isCompleted {
                    completedStoriesCount += 1
                    print("📚 MyWords: ✅ Story '\(story.title)' is completed")
                    
                    // Use Story's algorithm to find Quran words in story text
                    let matchedQuranWords = story.findQuranWordsInStory(from: quranWords)
                    print("📚 MyWords:   Found \(matchedQuranWords.count) Quran words in story")
                    
                    // Convert QuranWord to Word
                    for quranWord in matchedQuranWords {
                        let wordUUID = UUID(uuidString: quranWord.id) ?? UUID()
                        if !seenWordIds.contains(wordUUID) {
                            let word = Word(
                                id: wordUUID,
                                arabicText: quranWord.arabicText,
                                englishMeaning: quranWord.englishMeaning,
                                partOfSpeech: PartOfSpeech(rawValue: quranWord.morphology.partOfSpeech ?? "unknown"),
                                rootLetters: quranWord.root?.arabic,
                                difficulty: quranWord.rank <= 1000 ? 1 : quranWord.rank <= 5000 ? 2 : 3
                            )
                            collectedWords.append(word)
                            seenWordIds.insert(wordUUID)
                            totalMatchedWords += 1
                        }
                    }
                }
            }
            
            print("📚 MyWords: Found \(completedStoriesCount) completed stories with \(totalMatchedWords) matched Quran words")
            
            // Words only come from completed stories - no supplements
            
            await MainActor.run {
                self.unlockedWords = collectedWords
                self.loadMockMasteryData()
                self.isLoading = false
                print("📚 MyWords: Done! Loaded \(collectedWords.count) Quran words from stories")
            }
            
            // Load saved mastery data
            let savedMastery = await dataService.fetchWordMastery()
            await MainActor.run {
                self.wordMastery = savedMastery
                print("📚 MyWords: Loaded \(savedMastery.count) saved mastery entries")
            }
            
        } catch {
            print("📚 MyWords: Error loading words: \(error)")
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    private func loadMockMasteryData() {
        // Initialize words with zero progress - scores only come from actual quiz attempts
        for word in unlockedWords {
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
    
    private func generateQuestion(for word: Word) -> QuizQuestion? {
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
        
        // Get current question BEFORE answering (index will change after)
        guard let question = currentQuestion else { return }
        
        // Determine if answer is correct BEFORE processing
        let correct = (answer == question.correctAnswer)
        isCorrect = correct
        
        // Capture score before moving to next question
        let previousTotalScore = session?.totalScore ?? 0
        
        session?.answerCurrentQuestion(answer, responseTime: responseTime)
        
        // Calculate score earned for this answer
        let newTotalScore = session?.totalScore ?? 0
        lastScore = newTotalScore - previousTotalScore
        
        // Update word mastery based on answer
        updateWordMastery(word: question.word, isCorrect: correct, score: lastScore)
        
        // Play sound effect
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
    private func updateWordMastery(word: Word, isCorrect: Bool, score: Int) {
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
            mastery.totalScore += score
            mastery.timesCorrect += 1
            mastery.correctStreak += 1
            mastery.wrongStreak = 0
        } else {
            mastery.timesWrong += 1
            mastery.wrongStreak += 1
            mastery.correctStreak = 0
        }
        
        // Check if word is mastered (score >= 100)
        mastery.isMastered = mastery.totalScore >= 100
        
        wordMastery[word.id] = mastery
        
        print("📚 Word '\(word.arabicText)' mastery updated: score=\(mastery.totalScore), correct=\(mastery.timesCorrect), mastered=\(mastery.isMastered)")
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
        
        // Save mastery data
        Task {
            await dataService.saveWordMastery(wordMastery)
            print("💾 Saved word mastery data: \(wordMastery.count) entries")
        }
        
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
