//
//  ProgressViewModel.swift
//  Arabicly
//  ViewModel for user progress dashboard with Quran vocabulary tracking
//

import Foundation
import SwiftUI

@Observable
class ProgressViewModel {
    // Dependencies
    private let dataService = DataService.shared
    private let firebaseService = FirebaseService.shared
    
    // State
    var userProgress: UserProgress?
    var achievements: [Achievement] = []
    var isLoading = false
    var newlyUnlockedAchievement: Achievement?
    var newlyUnlockedAchievements: [Achievement] = []
    var showAchievementUnlocked = false
    
    // Level Management
    var maxUnlockedLevel: Int = 1
    var storyProgressToLevel2: Double = 0.0
    var storiesRemainingForLevel2: Int = 0
    var showLevelUnlockAlert: Bool = false
    
    // Statistics
    var totalStories: Int = 0
    var completedStories: Int = 0
    var totalLevel1Stories: Int = 0
    var completedLevel1Stories: Int = 0
    
    // Word Statistics (from MyWords/Quiz)
    var totalWordsUnlocked: Int = 0
    var totalWordsMastered: Int = 0
    var currentStreak: Int = 0
    
    // Daily Goal
    var todayStudyMinutes: Int = 0
    var dailyGoalMinutes: Int = 15
    
    // Quran Statistics
    var quranStats: QuranStats?
    var quranWordsLearnedCount: Int = 0
    var quranWordsMasteredCount: Int = 0
    var quranCompletionPercentage: Double = 0.0
    var totalOccurrencesLearned: Int = 0
    
    // Chart Data
    var weeklyStudyData: [StudyDayData] = []
    
    init() {
        Task {
            await loadData()
        }
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        await loadUserProgress()
        await loadQuranStats()
        await loadWordStats()
        await loadAchievements(checkForUnlocks: false)  // Don't show unlocks on initial load
        await loadStatistics()
    }
    
    /// Call this after story completion to check for newly unlocked achievements
    func checkAchievementsAfterStoryCompletion() async {
        await loadUserProgress()
        await loadWordStats()
        await loadAchievements(checkForUnlocks: true)  // Show unlocks after story completion
    }
    
    func loadUserProgress() async {
        userProgress = await dataService.fetchUserProgress()
        
        if let progress = userProgress {
            currentStreak = progress.currentStreak
            todayStudyMinutes = progress.todayStudyMinutes
            dailyGoalMinutes = progress.dailyGoalMinutes
            maxUnlockedLevel = progress.maxUnlockedLevel
            
            // Calculate story-based progress for Level 2
            let allStories = await dataService.fetchAllStories()
            let level1Stories = allStories.filter { $0.difficultyLevel == 1 }
            
            let allStoryProgress = await dataService.getAllStoryProgress()
            let completedStoryIds = Set(allStoryProgress.filter { $0.isCompleted }.map { $0.storyId })
            
            totalLevel1Stories = level1Stories.count
            completedLevel1Stories = level1Stories.filter { story in
                completedStoryIds.contains(story.id.uuidString)
            }.count
            
            storiesRemainingForLevel2 = totalLevel1Stories - completedLevel1Stories
            storyProgressToLevel2 = totalLevel1Stories > 0 
                ? Double(completedLevel1Stories) / Double(totalLevel1Stories) 
                : 0
            
            // Build weekly study data
            updateWeeklyStudyData(from: progress)
        }
    }
    
    func updateWeeklyStudyData(from progress: UserProgress) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
        
        var data: [StudyDayData] = []
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: monday) {
                let dayName = dayNames[i]
                let isToday = calendar.isDate(date, inSameDayAs: today)
                
                // Get minutes for this day from weeklyStudyMinutes
                var minutes = 0
                let daysDiff = calendar.dateComponents([.day], from: date, to: today).day ?? 0
                if daysDiff >= 0 && daysDiff < progress.weeklyStudyMinutes.count {
                    let index = progress.weeklyStudyMinutes.count - 1 - daysDiff
                    if index >= 0 && index < progress.weeklyStudyMinutes.count {
                        minutes = progress.weeklyStudyMinutes[index]
                    }
                }
                
                data.append(StudyDayData(day: dayName, minutes: minutes, isToday: isToday))
            }
        }
        
        weeklyStudyData = data
    }
    
    func loadQuranStats() async {
        do {
            quranStats = try await firebaseService.fetchQuranStats()
        } catch {
            print("Failed to load Quran stats: \(error)")
        }
    }
    
    func loadWordStats() async {
        // Load from MyWordsViewModel's word mastery data
        // This tracks words from completed stories
        let myWordsVM = MyWordsViewModel()
        await myWordsVM.loadUnlockedWords()
        
        totalWordsUnlocked = myWordsVM.unlockedWords.count
        totalWordsMastered = myWordsVM.masteredWords.count
        
        // Calculate Quran coverage
        if let stats = quranStats, stats.totalUniqueWords > 0 {
            quranWordsLearnedCount = totalWordsUnlocked
            quranWordsMasteredCount = totalWordsMastered
            
            // Calculate percentage based on unique words learned (not mastered)
            quranCompletionPercentage = Double(totalWordsUnlocked) / Double(stats.totalUniqueWords) * 100
            
            // Calculate total occurrences of learned words using actual Quran occurrence data
            totalOccurrencesLearned = myWordsVM.unlockedWords.reduce(0) { sum, word in
                // Use actual Quran occurrence count if available
                let occurrences = word.quranOccurrenceCount ?? 0
                return sum + occurrences
            }
        }
    }
    
    func loadAchievements(checkForUnlocks: Bool = false) async {
        var achievementsList = Achievement.defaultAchievements
        var newlyUnlocked: [Achievement] = []
        
        guard var progress = userProgress else {
            achievements = achievementsList
            return
        }
        
        // Track which achievements were already unlocked from persistent storage
        let previouslyUnlockedTitles = Set(progress.unlockedAchievementTitles)
        print("📖 Complete story: Previously unlocked achievements from storage: \(previouslyUnlockedTitles)")
        
        for index in achievementsList.indices {
            let achievementTitle = achievementsList[index].title
            let wasUnlocked = previouslyUnlockedTitles.contains(achievementTitle)
            
            // Set isUnlocked based on persistent storage
            achievementsList[index].isUnlocked = wasUnlocked
            
            switch achievementsList[index].category {
            case .vocabulary:
                updateVocabularyAchievement(&achievementsList[index], progress: progress)
                
            case .stories:
                achievementsList[index].currentProgress = progress.storiesCompleted
                if achievementsList[index].currentProgress >= achievementsList[index].requirement {
                    achievementsList[index].isUnlocked = true
                }
                
            case .streak:
                achievementsList[index].currentProgress = progress.currentStreak
                if achievementsList[index].currentProgress >= achievementsList[index].requirement {
                    achievementsList[index].isUnlocked = true
                }
                
            case .time:
                let hours = Int(progress.totalReadingTime / 3600)
                achievementsList[index].currentProgress = hours
                if achievementsList[index].currentProgress >= achievementsList[index].requirement {
                    achievementsList[index].isUnlocked = true
                }
                
            case .mastery:
                achievementsList[index].currentProgress = totalWordsMastered
                if achievementsList[index].currentProgress >= achievementsList[index].requirement {
                    achievementsList[index].isUnlocked = true
                }
                
            default:
                break
            }
            
            // Check if newly unlocked (wasn't unlocked before but is now)
            if !wasUnlocked && achievementsList[index].isUnlocked {
                print("📖 Complete story: Newly unlocked: \(achievementTitle)")
                newlyUnlocked.append(achievementsList[index])
                
                // Save to persistent storage
                if !progress.unlockedAchievementTitles.contains(achievementTitle) {
                    progress.unlockedAchievementTitles.append(achievementTitle)
                }
            }
        }
        
        achievements = achievementsList
        newlyUnlockedAchievements = newlyUnlocked

        // Save updated progress with new achievements
        if !newlyUnlocked.isEmpty {
            try? await dataService.updateUserProgress(progress)
            print("📖 Complete story: Saved \(newlyUnlocked.count) new achievements to storage")
        }

        // Only show notification when checkForUnlocks is true (after story completion)
        if checkForUnlocks, let firstNew = newlyUnlocked.first {
            print("📖 Complete story: Showing achievement popup for: \(firstNew.title)")
            newlyUnlockedAchievement = firstNew
            showAchievementUnlocked = true
        } else if checkForUnlocks {
            print("📖 Complete story: No new achievements to show")
        }
    }
    
    private func updateVocabularyAchievement(_ achievement: inout Achievement, progress: UserProgress) {
        switch achievement.title {
        case "Word Seeker":
            achievement.currentProgress = min(totalWordsUnlocked, 5)
        case "Vocabulary Builder":
            achievement.currentProgress = min(totalWordsUnlocked, 20)
        case "Word Collector":
            achievement.currentProgress = min(totalWordsUnlocked, 50)
        case "Lexicon Master":
            achievement.currentProgress = min(totalWordsMastered, 200)
        case "Level Up!":
            achievement.currentProgress = min(totalWordsMastered, 20)
        default:
            achievement.currentProgress = min(totalWordsUnlocked, achievement.requirement)
        }
        
        if achievement.currentProgress >= achievement.requirement {
            achievement.isUnlocked = true
        }
    }
    
    func loadStatistics() async {
        let stories = await dataService.fetchAllStories()
        totalStories = stories.count
        
        let allStoryProgress = await dataService.getAllStoryProgress()
        completedStories = allStoryProgress.filter { $0.isCompleted }.count
    }
    
    func refresh() async {
        await loadData()
    }
    
    // MARK: - Actions
    
    func recordReadingSession(minutes: Int) async {
        guard var progress = userProgress else { return }
        progress.recordStudySession(minutes: minutes)
        try? await dataService.updateUserProgress(progress)
        await loadUserProgress()
    }
    
    func updateDailyGoal(minutes: Int) async {
        dailyGoalMinutes = minutes
        
        if var progress = userProgress {
            progress.dailyGoalMinutes = minutes
            try? await dataService.updateUserProgress(progress)
        }
    }
    
    func acknowledgeAchievement() {
        showAchievementUnlocked = false
        newlyUnlockedAchievement = nil
    }
    
    // MARK: - Computed Properties
    
    var dailyGoalProgress: Double {
        min(Double(todayStudyMinutes) / Double(dailyGoalMinutes), 1.0)
    }
    
    var isDailyGoalCompleted: Bool {
        todayStudyMinutes >= dailyGoalMinutes
    }
    
    var completionRate: Double {
        guard totalStories > 0 else { return 0 }
        return Double(completedStories) / Double(totalStories)
    }
    
    var unlockedAchievements: [Achievement] {
        achievements.filter { $0.isUnlocked }.sorted { $0.rarity.rawValue > $1.rarity.rawValue }
    }
    
    var lockedAchievements: [Achievement] {
        achievements.filter { !$0.isUnlocked }
    }
    
    var achievementsByCategory: [AchievementCategory: [Achievement]] {
        Dictionary(grouping: achievements) { $0.category }
    }
    
    var weeklyTotalMinutes: Int {
        weeklyStudyData.reduce(0) { $0 + $1.minutes }
    }
    
    var averageDailyMinutes: Int {
        guard !weeklyStudyData.isEmpty else { return 0 }
        return weeklyTotalMinutes / weeklyStudyData.count
    }
    
    var quickStats: [QuickStats] {
        [
            QuickStats(
                label: "Current Streak",
                value: "\(currentStreak) days",
                icon: "flame.fill",
                color: .orange
            ),
            QuickStats(
                label: "Words Unlocked",
                value: "\(totalWordsUnlocked)",
                icon: "textformat.abc",
                color: .blue
            ),
            QuickStats(
                label: "Words Mastered",
                value: "\(totalWordsMastered)",
                icon: "star.fill",
                color: .yellow
            ),
            QuickStats(
                label: "Stories Read",
                value: "\(completedStories)",
                icon: "book.fill",
                color: .green
            )
        ]
    }
}

// MARK: - Quick Stats

struct QuickStats {
    let label: String
    let value: String
    let icon: String
    let color: Color
}


