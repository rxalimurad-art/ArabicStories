//
//  UserProgress.swift
//  Arabicly
//  User progress tracking - Firebase compatible (no SwiftData)
//

import Foundation

struct UserProgress: Identifiable, Codable {
    // MARK: - Singleton-like identifier
    var id: String
    
    // MARK: - Level Unlocking
    var maxUnlockedLevel: Int
    var vocabularyNeededForLevel2: Int
    
    // MARK: - Streak Tracking
    var currentStreak: Int
    var longestStreak: Int
    var lastStudyDate: Date?
    var streakFreezeUsed: Bool
    var streakFreezeDate: Date?
    
    // MARK: - Word Statistics
    var totalWordsLearned: Int
    var totalWordsMastered: Int
    var wordsUnderReview: Int
    
    // MARK: - Vocabulary Tracking (for Level 1 -> Level 2 unlock)
    var learnedVocabularyIds: [String]
    var masteredVocabularyIds: [String]
    var totalVocabularyLearned: Int {
        learnedVocabularyIds.count
    }
    
    // MARK: - Story Statistics
    var storiesCompleted: Int
    var storiesInProgress: Int
    var level1StoriesCompleted: Int
    var level2StoriesCompleted: Int
    var totalReadingTime: TimeInterval
    var totalPagesRead: Int
    
    // MARK: - Story Completion Tracking for Level Unlock
    var completedStoryIds: [String]
    
    // MARK: - Session Tracking
    var dailyGoalMinutes: Int
    var todayStudyMinutes: Int
    var weeklyStudyMinutes: [Int]
    
    // MARK: - Weak Words (for targeted practice)
    var weakWordIds: [String]
    
    // MARK: - Timestamps
    var createdAt: Date
    var updatedAt: Date
    
    init() {
        self.id = "user_progress"
        self.maxUnlockedLevel = 1  // Start with Level 1 only
        self.vocabularyNeededForLevel2 = 20  // Need 20 words to unlock Level 2
        self.currentStreak = 0
        self.longestStreak = 0
        self.streakFreezeUsed = false
        self.totalWordsLearned = 0
        self.totalWordsMastered = 0
        self.wordsUnderReview = 0
        self.learnedVocabularyIds = []
        self.masteredVocabularyIds = []
        self.completedStoryIds = []
        self.storiesCompleted = 0
        self.storiesInProgress = 0
        self.level1StoriesCompleted = 0
        self.level2StoriesCompleted = 0
        self.totalReadingTime = 0
        self.totalPagesRead = 0
        self.dailyGoalMinutes = 5  // Default 5 minutes daily goal
        self.todayStudyMinutes = 0
        self.weeklyStudyMinutes = Array(repeating: 0, count: 7)
        self.weakWordIds = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Level Management
    
    var canAccessLevel2: Bool {
        totalVocabularyLearned >= vocabularyNeededForLevel2
    }
    
    var vocabularyProgressToLevel2: Double {
        min(Double(totalVocabularyLearned) / Double(vocabularyNeededForLevel2), 1.0)
    }
    
    var vocabularyRemainingForLevel2: Int {
        max(vocabularyNeededForLevel2 - totalVocabularyLearned, 0)
    }
    
    /// Check if all stories in a level are completed
    func areAllStoriesCompleted(level: Int, totalStoriesInLevel: Int) -> Bool {
        // Count completed stories for this level
        let completedInLevel = completedStoryIds.count
        return completedInLevel >= totalStoriesInLevel && totalStoriesInLevel > 0
    }
    
    /// Progress to unlock next level (based on story completion)
    func storyProgressToUnlockLevel(level: Int, totalStoriesInLevel: Int) -> Double {
        guard totalStoriesInLevel > 0 else { return 0 }
        let completedInLevel = completedStoryIds.count
        return min(Double(completedInLevel) / Double(totalStoriesInLevel), 1.0)
    }
    
    /// Remaining stories to complete to unlock next level
    func storiesRemainingToUnlockLevel(level: Int, totalStoriesInLevel: Int) -> Int {
        guard totalStoriesInLevel > 0 else { return 0 }
        let completedInLevel = completedStoryIds.count
        return max(totalStoriesInLevel - completedInLevel, 0)
    }
    
    mutating func checkAndUnlockLevel2(totalStoriesInLevel1: Int) -> Bool {
        if maxUnlockedLevel < 2 && areAllStoriesCompleted(level: 1, totalStoriesInLevel: totalStoriesInLevel1) {
            maxUnlockedLevel = 2
            updatedAt = Date()
            return true
        }
        return false
    }
    
    // MARK: - Vocabulary Learning
    
    mutating func recordVocabularyLearned(wordId: String) {
        if !learnedVocabularyIds.contains(wordId) {
            learnedVocabularyIds.append(wordId)
            updatedAt = Date()
            // Note: Level 2 is now unlocked by completing all Level 1 stories, not by vocabulary
        }
    }
    
    mutating func recordVocabularyMastered(wordId: String) {
        if !masteredVocabularyIds.contains(wordId) {
            masteredVocabularyIds.append(wordId)
        }
        if !learnedVocabularyIds.contains(wordId) {
            learnedVocabularyIds.append(wordId)
        }
        updatedAt = Date()
        // Note: Level 2 is now unlocked by completing all Level 1 stories, not by vocabulary
    }
    
    func hasLearnedVocabulary(_ wordId: String) -> Bool {
        learnedVocabularyIds.contains(wordId)
    }
    
    func hasMasteredVocabulary(_ wordId: String) -> Bool {
        masteredVocabularyIds.contains(wordId)
    }
    
    // MARK: - Streak Management
    
    mutating func recordStudySession(minutes: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        todayStudyMinutes += minutes
        weeklyStudyMinutes[6] = todayStudyMinutes
        
        if let lastDate = lastStudyDate {
            let lastStudyDay = calendar.startOfDay(for: lastDate)
            let daysSinceLastStudy = calendar.dateComponents([.day], from: lastStudyDay, to: today).day ?? 0
            
            if daysSinceLastStudy == 1 {
                currentStreak += 1
                if currentStreak > longestStreak {
                    longestStreak = currentStreak
                }
            } else if daysSinceLastStudy > 1 {
                if !streakFreezeUsed && daysSinceLastStudy == 2 {
                    streakFreezeUsed = true
                    streakFreezeDate = lastDate
                } else {
                    currentStreak = 1
                }
            }
        } else {
            currentStreak = 1
            longestStreak = 1
        }
        
        lastStudyDate = Date()
        updatedAt = Date()
        updateWeeklyStats()
    }
    
    mutating func updateWeeklyStats() {
        while weeklyStudyMinutes.count < 7 {
            weeklyStudyMinutes.insert(0, at: 0)
        }
        if weeklyStudyMinutes.count > 7 {
            weeklyStudyMinutes = Array(weeklyStudyMinutes.suffix(7))
        }
    }
    
    // MARK: - Word Progress
    
    mutating func recordWordLearned(wordId: String, isNew: Bool) {
        if isNew {
            totalWordsLearned += 1
        }
        updatedAt = Date()
    }
    
    mutating func recordWordMastered(wordId: String) {
        totalWordsMastered += 1
        weakWordIds.removeAll { $0 == wordId }
        updatedAt = Date()
    }
    
    mutating func addWeakWord(wordId: String) {
        if !weakWordIds.contains(wordId) {
            weakWordIds.append(wordId)
            if weakWordIds.count > 50 {
                weakWordIds.removeFirst()
            }
        }
        updatedAt = Date()
    }
    
    // MARK: - Story Progress
    
    mutating func recordStoryCompleted(storyId: String, difficultyLevel: Int, totalStoriesInLevel1: Int) -> Bool {
        // Track completed story ID if not already tracked
        if !completedStoryIds.contains(storyId) {
            completedStoryIds.append(storyId)
        }
        
        storiesCompleted += 1
        if difficultyLevel == 1 {
            level1StoriesCompleted += 1
        } else if difficultyLevel >= 2 {
            level2StoriesCompleted += 1
        }
        updatedAt = Date()
        
        // Check if Level 2 should be unlocked
        return checkAndUnlockLevel2(totalStoriesInLevel1: totalStoriesInLevel1)
    }
    
    mutating func recordStoryStarted() {
        storiesInProgress += 1
        updatedAt = Date()
    }
    
    mutating func recordReadingTime(_ time: TimeInterval) {
        totalReadingTime += time
        updatedAt = Date()
    }
    
    mutating func recordPagesRead(_ pages: Int) {
        totalPagesRead += pages
        updatedAt = Date()
    }
    
    // MARK: - Computed Properties
    var dailyGoalProgress: Double {
        min(Double(todayStudyMinutes) / Double(dailyGoalMinutes), 1.0)
    }
    
    var isDailyGoalCompleted: Bool {
        todayStudyMinutes >= dailyGoalMinutes
    }
    
    var totalStudyHours: Double {
        totalReadingTime / 3600.0
    }
    
    var weeklyTotalMinutes: Int {
        weeklyStudyMinutes.reduce(0, +)
    }
    
    var averageDailyMinutes: Int {
        let daysSinceStart = Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 1
        return Int(totalReadingTime / 60.0) / max(daysSinceStart, 1)
    }
    
    mutating func resetDailyStats() {
        todayStudyMinutes = 0
        weeklyStudyMinutes.append(0)
        if weeklyStudyMinutes.count > 7 {
            weeklyStudyMinutes.removeFirst()
        }
        streakFreezeUsed = false
        streakFreezeDate = nil
    }
}

// MARK: - Achievement Model

struct Achievement: Identifiable, Codable {
    var id: UUID
    var title: String
    var achievementDescription: String
    var iconName: String
    var category: AchievementCategory
    var requirement: Int
    var currentProgress: Int
    var isUnlocked: Bool
    var unlockedDate: Date?
    var rarity: AchievementRarity
    
    init(
        id: UUID = UUID(),
        title: String,
        achievementDescription: String,
        iconName: String,
        category: AchievementCategory,
        requirement: Int,
        rarity: AchievementRarity = .common
    ) {
        self.id = id
        self.title = title
        self.achievementDescription = achievementDescription
        self.iconName = iconName
        self.category = category
        self.requirement = requirement
        self.currentProgress = 0
        self.isUnlocked = false
        self.rarity = rarity
    }
    
    mutating func updateProgress(_ progress: Int) {
        currentProgress = progress
        if currentProgress >= requirement && !isUnlocked {
            unlock()
        }
    }
    
    mutating func unlock() {
        isUnlocked = true
        unlockedDate = Date()
    }
    
    var progressPercentage: Double {
        min(Double(currentProgress) / Double(requirement), 1.0)
    }
}

enum AchievementCategory: String, Codable, CaseIterable {
    case streak = "streak"
    case words = "words"
    case stories = "stories"
    case time = "time"
    case mastery = "mastery"
    case social = "social"
    case vocabulary = "vocabulary"
    
    var displayName: String {
        rawValue.capitalized
    }
}

enum AchievementRarity: String, Codable, CaseIterable {
    case common = "common"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var color: String {
        switch self {
        case .common: return "gray"
        case .rare: return "blue"
        case .epic: return "purple"
        case .legendary: return "orange"
        }
    }
}

// MARK: - Default Achievements

extension Achievement {
    static let defaultAchievements: [Achievement] = [
        // Streak achievements
        Achievement(title: "First Step", achievementDescription: "Complete your first study session", iconName: "figure.walk", category: .streak, requirement: 1, rarity: .common),
        Achievement(title: "Week Warrior", achievementDescription: "Maintain a 7-day streak", iconName: "flame.fill", category: .streak, requirement: 7, rarity: .rare),
        Achievement(title: "Month Master", achievementDescription: "Maintain a 30-day streak", iconName: "crown.fill", category: .streak, requirement: 30, rarity: .epic),
        Achievement(title: "Centurion", achievementDescription: "Maintain a 100-day streak", iconName: "star.circle.fill", category: .streak, requirement: 100, rarity: .legendary),
        
        // Vocabulary achievements (new)
        Achievement(title: "Word Seeker", achievementDescription: "Learn 5 Arabic words", iconName: "character", category: .vocabulary, requirement: 5, rarity: .common),
        Achievement(title: "Vocabulary Builder", achievementDescription: "Learn 20 Arabic words", iconName: "textformat.abc", category: .vocabulary, requirement: 20, rarity: .rare),
        Achievement(title: "Word Collector", achievementDescription: "Learn 50 words", iconName: "character.book.closed", category: .vocabulary, requirement: 50, rarity: .common),
        Achievement(title: "Lexicon Master", achievementDescription: "Learn 200 words", iconName: "text.book.closed.fill", category: .vocabulary, requirement: 200, rarity: .epic),
        Achievement(title: "Level Up!", achievementDescription: "Unlock Level 2 by learning 20 words", iconName: "arrow.up.circle.fill", category: .vocabulary, requirement: 20, rarity: .rare),
        
        // Story achievements
        Achievement(title: "Story Starter", achievementDescription: "Complete your first story", iconName: "book.open.fill", category: .stories, requirement: 1, rarity: .common),
        Achievement(title: "Bookworm", achievementDescription: "Complete 10 stories", iconName: "books.vertical.fill", category: .stories, requirement: 10, rarity: .rare),
        Achievement(title: "Literary Scholar", achievementDescription: "Complete 50 stories", iconName: "graduationcap.fill", category: .stories, requirement: 50, rarity: .epic),
        
        // Time achievements
        Achievement(title: "Dedicated Student", achievementDescription: "Study for 10 hours total", iconName: "clock.fill", category: .time, requirement: 10, rarity: .common),
        Achievement(title: "Time Keeper", achievementDescription: "Study for 50 hours total", iconName: "timer", category: .time, requirement: 50, rarity: .rare),
        Achievement(title: "Time Lord", achievementDescription: "Study for 200 hours total", iconName: "hourglass", category: .time, requirement: 200, rarity: .epic),
        
        // Mastery achievements
        Achievement(title: "Word Master", achievementDescription: "Master 100 words", iconName: "checkmark.seal.fill", category: .mastery, requirement: 100, rarity: .rare),
        Achievement(title: "Fluency Seeker", achievementDescription: "Master 500 words", iconName: "sparkles", category: .mastery, requirement: 500, rarity: .epic)
    ]
}

// MARK: - Study Day Data

struct StudyDayData: Identifiable {
    let id = UUID()
    let day: String
    let minutes: Int
    var isToday: Bool = false
}

// MARK: - Level Unlock Info

struct LevelUnlockInfo {
    let level: Int
    let requiredVocabulary: Int
    let title: String
    let description: String
    
    static let level2 = LevelUnlockInfo(
        level: 2,
        requiredVocabulary: 0,  // No longer vocabulary-based
        title: "Level 2 Unlocked!",
        description: "You've completed all Level 1 stories and can now read full Arabic stories."
    )
}
