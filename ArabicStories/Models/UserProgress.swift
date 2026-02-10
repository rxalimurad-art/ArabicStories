//
//  UserProgress.swift
//  Hikaya
//  User progress tracking - Firebase compatible (no SwiftData)
//

import Foundation

struct UserProgress: Identifiable, Codable {
    // MARK: - Singleton-like identifier
    var id: String
    
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
    
    // MARK: - Story Statistics
    var storiesCompleted: Int
    var storiesInProgress: Int
    var totalReadingTime: TimeInterval
    var totalPagesRead: Int
    
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
        self.currentStreak = 0
        self.longestStreak = 0
        self.streakFreezeUsed = false
        self.totalWordsLearned = 0
        self.totalWordsMastered = 0
        self.wordsUnderReview = 0
        self.storiesCompleted = 0
        self.storiesInProgress = 0
        self.totalReadingTime = 0
        self.totalPagesRead = 0
        self.dailyGoalMinutes = 15
        self.todayStudyMinutes = 0
        self.weeklyStudyMinutes = Array(repeating: 0, count: 7)
        self.weakWordIds = []
        self.createdAt = Date()
        self.updatedAt = Date()
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
    mutating func recordStoryCompleted() {
        storiesCompleted += 1
        updatedAt = Date()
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
        Achievement(title: "First Step", achievementDescription: "Complete your first study session", iconName: "figure.walk", category: .streak, requirement: 1, rarity: .common),
        Achievement(title: "Week Warrior", achievementDescription: "Maintain a 7-day streak", iconName: "flame.fill", category: .streak, requirement: 7, rarity: .rare),
        Achievement(title: "Month Master", achievementDescription: "Maintain a 30-day streak", iconName: "crown.fill", category: .streak, requirement: 30, rarity: .epic),
        Achievement(title: "Centurion", achievementDescription: "Maintain a 100-day streak", iconName: "star.circle.fill", category: .streak, requirement: 100, rarity: .legendary),
        Achievement(title: "Word Collector", achievementDescription: "Learn 50 words", iconName: "textformat.abc", category: .words, requirement: 50, rarity: .common),
        Achievement(title: "Vocabulary Builder", achievementDescription: "Learn 200 words", iconName: "book.fill", category: .words, requirement: 200, rarity: .rare),
        Achievement(title: "Lexicon Master", achievementDescription: "Learn 500 words", iconName: "text.book.closed.fill", category: .words, requirement: 500, rarity: .epic),
        Achievement(title: "Story Starter", achievementDescription: "Complete your first story", iconName: "book.open.fill", category: .stories, requirement: 1, rarity: .common),
        Achievement(title: "Bookworm", achievementDescription: "Complete 10 stories", iconName: "books.vertical.fill", category: .stories, requirement: 10, rarity: .rare),
        Achievement(title: "Literary Scholar", achievementDescription: "Complete 50 stories", iconName: "graduationcap.fill", category: .stories, requirement: 50, rarity: .epic),
        Achievement(title: "Dedicated Student", achievementDescription: "Study for 10 hours total", iconName: "clock.fill", category: .time, requirement: 10, rarity: .common),
        Achievement(title: "Time Keeper", achievementDescription: "Study for 50 hours total", iconName: "timer", category: .time, requirement: 50, rarity: .rare),
        Achievement(title: "Time Lord", achievementDescription: "Study for 200 hours total", iconName: "hourglass", category: .time, requirement: 200, rarity: .epic),
        Achievement(title: "Word Master", achievementDescription: "Master 100 words", iconName: "checkmark.seal.fill", category: .mastery, requirement: 100, rarity: .rare),
        Achievement(title: "Fluency Seeker", achievementDescription: "Master 500 words", iconName: "sparkles", category: .mastery, requirement: 500, rarity: .epic)
    ]
}

// MARK: - Study Day Data

struct StudyDayData: Identifiable {
    let id = UUID()
    let day: String
    let minutes: Int
}
