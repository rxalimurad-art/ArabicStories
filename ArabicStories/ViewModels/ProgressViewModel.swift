//
//  ProgressViewModel.swift
//  Hikaya
//  ViewModel for user progress dashboard with vocabulary tracking
//

import Foundation
import SwiftUI

@Observable
class ProgressViewModel {
    // Dependencies
    private let dataService = DataService.shared
    
    // State
    var userProgress: UserProgress?
    var achievements: [Achievement] = []
    var recentStories: [Story] = []
    var weakWords: [Word] = []
    var isLoading = false
    
    // Level Management
    var maxUnlockedLevel: Int = 1
    var vocabularyProgressToLevel2: Double = 0.0
    var vocabularyRemainingForLevel2: Int = 20
    var showLevelUnlockAlert: Bool = false
    
    // Statistics
    var totalStories: Int = 0
    var completedStories: Int = 0
    var totalWords: Int = 0
    var masteredWords: Int = 0
    var currentStreak: Int = 0
    var todayStudyMinutes: Int = 0
    var dailyGoalMinutes: Int = 15
    
    // Vocabulary Statistics
    var totalVocabularyLearned: Int = 0
    var totalVocabularyMastered: Int = 0
    var vocabularyNeededForLevel2: Int = 20
    
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
        await loadAchievements()
        await loadRecentStories()
        await loadWeakWords()
        await loadStatistics()
    }
    
    func loadUserProgress() async {
        userProgress = await dataService.fetchUserProgress()
        
        if let progress = userProgress {
            currentStreak = progress.currentStreak
            todayStudyMinutes = progress.todayStudyMinutes
            dailyGoalMinutes = progress.dailyGoalMinutes
            maxUnlockedLevel = progress.maxUnlockedLevel
            vocabularyProgressToLevel2 = progress.vocabularyProgressToLevel2
            vocabularyRemainingForLevel2 = progress.vocabularyRemainingForLevel2
            totalVocabularyLearned = progress.totalVocabularyLearned
            totalVocabularyMastered = progress.masteredVocabularyIds.count
            vocabularyNeededForLevel2 = progress.vocabularyNeededForLevel2
            
            // Convert weekly data
            let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            weeklyStudyData = progress.weeklyStudyMinutes.enumerated().map { index, minutes in
                StudyDayData(day: days[index], minutes: minutes)
            }
        }
    }
    
    func loadAchievements() async {
        var achievementsList = Achievement.defaultAchievements
        
        // Update progress for vocabulary achievements
        if let progress = userProgress {
            for index in achievementsList.indices {
                switch achievementsList[index].category {
                case .vocabulary:
                    if achievementsList[index].title == "Word Seeker" {
                        achievementsList[index].currentProgress = min(progress.totalVocabularyLearned, 5)
                    } else if achievementsList[index].title == "Vocabulary Builder" {
                        achievementsList[index].currentProgress = min(progress.totalVocabularyLearned, 20)
                    } else if achievementsList[index].title == "Level Up!" {
                        achievementsList[index].currentProgress = min(progress.totalVocabularyLearned, 20)
                    } else if achievementsList[index].title == "Word Collector" {
                        achievementsList[index].currentProgress = min(progress.totalVocabularyLearned, 50)
                    } else if achievementsList[index].title == "Lexicon Master" {
                        achievementsList[index].currentProgress = min(progress.totalVocabularyLearned, 200)
                    }
                    
                    // Check if should be unlocked
                    if achievementsList[index].currentProgress >= achievementsList[index].requirement {
                        achievementsList[index].isUnlocked = true
                    }
                    
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
                    
                default:
                    break
                }
            }
        }
        
        achievements = achievementsList
    }
    
    func loadRecentStories() async {
        recentStories = await dataService.fetchStories(
            sortBy: .recentlyRead
        ).filter { $0.lastReadDate != nil }
        .prefix(5)
        .map { $0 }
    }
    
    func loadWeakWords() async {
        guard let progress = userProgress else { return }
        
        let allWords = await dataService.fetchAllWords()
        weakWords = allWords
            .filter { progress.weakWordIds.contains($0.id.uuidString) }
            .prefix(10)
            .map { $0 }
    }
    
    func loadStatistics() async {
        let stories = await dataService.fetchAllStories()
        totalStories = stories.count
        completedStories = stories.filter { $0.isCompleted }.count
        
        let allWords = await dataService.fetchAllWords()
        totalWords = allWords.count
        masteredWords = allWords.filter { ($0.masteryLevel ?? .new) == .mastered || ($0.masteryLevel ?? .new) == .known }.count
    }
    
    func refresh() async {
        await loadData()
    }
    
    // MARK: - Actions
    
    func recordStudySession(minutes: Int) async {
        await dataService.recordStudySession(minutes: minutes)
        await loadUserProgress()
    }
    
    func updateDailyGoal(minutes: Int) async {
        dailyGoalMinutes = minutes
        
        if var progress = userProgress {
            progress.dailyGoalMinutes = minutes
            try? await dataService.updateUserProgress(progress)
        }
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
    
    var masteryRate: Double {
        guard totalWords > 0 else { return 0 }
        return Double(masteredWords) / Double(totalWords)
    }
    
    var unlockedAchievements: [Achievement] {
        achievements.filter { $0.isUnlocked }
    }
    
    var lockedAchievements: [Achievement] {
        achievements.filter { !$0.isUnlocked }
    }
    
    var achievementsByCategory: [AchievementCategory: [Achievement]] {
        Dictionary(grouping: achievements) { $0.category }
    }
    
    var continueReadingStories: [Story] {
        recentStories.filter { $0.isInProgress }
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
                label: "Words Learned",
                value: "\(totalVocabularyLearned)",
                icon: "textformat.abc",
                color: .blue
            ),
            QuickStats(
                label: "Stories Read",
                value: "\(completedStories)",
                icon: "book.fill",
                color: .green
            ),
            QuickStats(
                label: "Study Time",
                value: formatTime(userProgress?.totalReadingTime ?? 0),
                icon: "clock.fill",
                color: .purple
            )
        ]
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        if hours > 0 {
            return "\(hours)h"
        } else {
            let minutes = Int(timeInterval) / 60
            return "\(minutes)m"
        }
    }
}

// MARK: - Quick Stats

struct QuickStats {
    let label: String
    let value: String
    let icon: String
    let color: Color
}
