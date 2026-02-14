//
//  ProgressDashboardView.swift
//  Arabicly
//  User progress dashboard with statistics and achievements
//

import SwiftUI

struct ProgressDashboardView: View {
    @State private var viewModel = ProgressViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.hikayaBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Level Status Card
                        LevelStatusCard(viewModel: viewModel)
                        
                        // Streak Card
                        StreakCard(viewModel: viewModel)
                        
                        // Quick Stats Grid
                        QuickStatsGrid(viewModel: viewModel)
                        
                        // Vocabulary Progress Card (if Level 2 not unlocked)
                        if viewModel.maxUnlockedLevel < 2 {
                            VocabularyProgressCard(viewModel: viewModel)
                        }
                        
                        // Weekly Progress Chart
                        WeeklyProgressCard(viewModel: viewModel)
                        
                        // Continue Reading Section
                        if !viewModel.continueReadingStories.isEmpty {
                            ContinueReadingSection(viewModel: viewModel)
                        }
                        
                        // Achievements Section
                        AchievementsSection(viewModel: viewModel)
                    }
                    .padding()
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .alert("🎉 Level 2 Unlocked!", isPresented: $viewModel.showLevelUnlockAlert) {
                Button("Awesome!", role: .cancel) {}
            } message: {
                Text("You've completed all Level 1 stories! Level 2 with full Arabic stories is now available.")
            }
        }
    }
}

// MARK: - Level Status Card

struct LevelStatusCard: View {
    var viewModel: ProgressViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Level")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("Level \(viewModel.maxUnlockedLevel)")
                        .font(.title.weight(.bold))
                        .foregroundStyle(Color.hikayaTeal)
                }
                
                Spacer()
                
                // Level indicator
                ZStack {
                    Circle()
                        .fill(Color.hikayaTeal.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: viewModel.maxUnlockedLevel >= 2 ? "crown.fill" : "book.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.hikayaTeal)
                }
            }
            
            if viewModel.maxUnlockedLevel < 2 {
                Divider()
                
                HStack {
                    Image(systemName: "lock.open.fill")
                        .foregroundStyle(Color.hikayaOrange)
                    
                    Text("Complete \(viewModel.storiesRemainingForLevel2) more Level 1 stor\(viewModel.storiesRemainingForLevel2 == 1 ? "y" : "ies") to unlock Level 2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
            } else {
                Divider()
                
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    
                    Text("Level 2 unlocked! Full Arabic stories available.")
                        .font(.caption)
                        .foregroundStyle(.green)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.hikayaTeal.opacity(0.1), Color.hikayaCream],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.hikayaTeal.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Streak Card

struct StreakCard: View {
    var viewModel: ProgressViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Streak")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("\(viewModel.currentStreak) days")
                        .font(.title.weight(.bold))
                        .foregroundStyle(Color.hikayaOrange)
                }
                
                Spacer()
                
                // Flame Icon with Animation
                ZStack {
                    Circle()
                        .fill(Color.hikayaOrange.opacity(0.2))
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: "flame.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(viewModel.currentStreak > 0 ? Color.hikayaOrange : Color.gray)
                }
            }
            
            Divider()
            
            // Daily Goal Progress
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Daily Goal")
                        .font(.subheadline.weight(.medium))
                    
                    Spacer()
                    
                    Text("\(viewModel.todayStudyMinutes)/\(viewModel.dailyGoalMinutes) min")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(viewModel.isDailyGoalCompleted ? .green : .secondary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(viewModel.isDailyGoalCompleted ? Color.green : Color.hikayaTeal)
                            .frame(width: geometry.size.width * viewModel.dailyGoalProgress, height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.hikayaOrange.opacity(0.15), Color.hikayaCream],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.hikayaOrange.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Quick Stats Grid

struct QuickStatsGrid: View {
    var viewModel: ProgressViewModel
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(viewModel.quickStats, id: \.label) { stat in
                QuickStatCard(stat: stat)
            }
        }
    }
}

// MARK: - Quick Stat Card

struct QuickStatCard: View {
    let stat: QuickStats
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: stat.icon)
                .font(.title3)
                .foregroundStyle(stat.color)
                .frame(width: 44, height: 44)
                .background(stat.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.value)
                    .font(.headline.weight(.semibold))
                
                Text(stat.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Vocabulary Progress Card

struct VocabularyProgressCard: View {
    var viewModel: ProgressViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vocabulary Progress")
                        .font(.headline.weight(.semibold))
                    
                    Text("\(viewModel.totalVocabularyLearned) of \(viewModel.vocabularyNeededForLevel2) words to unlock Level 2")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.hikayaTeal.opacity(0.2), lineWidth: 6)
                        .frame(width: 56, height: 56)
                    
                    Circle()
                        .trim(from: 0, to: viewModel.storyProgressToLevel2)
                        .stroke(
                            Color.hikayaTeal,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(viewModel.storyProgressToLevel2 * 100))%")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.hikayaTeal)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.hikayaTeal, Color.hikayaTeal.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * viewModel.storyProgressToLevel2, height: 12)
                }
            }
            .frame(height: 12)
            
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Color.hikayaOrange)
                    .font(.caption)
                
                Text("Tip: Complete all Level 1 stories to unlock Level 2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Weekly Progress Card

struct WeeklyProgressCard: View {
    var viewModel: ProgressViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Progress")
                        .font(.headline.weight(.semibold))
                    
                    Text("\(viewModel.weeklyTotalMinutes) minutes this week")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("Avg: \(viewModel.averageDailyMinutes)m/day")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.hikayaTeal.opacity(0.15))
                    .foregroundStyle(Color.hikayaTeal)
                    .clipShape(Capsule())
            }
            
            // Bar Chart
            HStack(spacing: 8) {
                ForEach(viewModel.weeklyStudyData) { day in
                    VStack(spacing: 6) {
                        // Bar
                        GeometryReader { geometry in
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))
                                
                                if day.minutes > 0 {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.hikayaTeal)
                                        .frame(height: geometry.size.height * CGFloat(day.minutes) / 60.0)
                                }
                            }
                        }
                        .frame(height: 80)
                        
                        // Day Label
                        Text(day.day)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Continue Reading Section

struct ContinueReadingSection: View {
    var viewModel: ProgressViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue Reading")
                .font(.headline.weight(.semibold))
            
            LazyVStack(spacing: 10) {
                ForEach(viewModel.continueReadingStories.prefix(3)) { story in
                    let progress = viewModel.getStoryProgress(story.id)
                    ContinueReadingCard(story: story, progress: progress)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Continue Reading Card

struct ContinueReadingCard: View {
    let story: Story
    let progress: StoryProgress?
    
    private var readingProgress: Double {
        progress?.readingProgress ?? 0.0
    }
    
    var body: some View {
        NavigationLink(value: story) {
            HStack(spacing: 12) {
                // Cover Thumbnail
                StoryCoverImage(url: story.coverImageURL)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(story.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    
                    Text("\(Int(readingProgress * 100))% complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Mini Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(.systemGray5))
                                .frame(height: 3)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.hikayaTeal)
                                .frame(width: geometry.size.width * readingProgress, height: 3)
                        }
                    }
                    .frame(height: 3)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .navigationDestination(for: Story.self) { story in
            StoryReaderView(story: story)
        }
    }
}

// MARK: - Achievements Section

struct AchievementsSection: View {
    var viewModel: ProgressViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Achievements")
                    .font(.headline.weight(.semibold))
                
                Spacer()
                
                Text("\(viewModel.unlockedAchievements.count)/\(viewModel.achievements.count)")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.hikayaOrange.opacity(0.15))
                    .foregroundStyle(Color.hikayaOrange)
                    .clipShape(Capsule())
            }
            
            // Achievement Grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                ForEach(viewModel.achievements.prefix(6)) { achievement in
                    AchievementBadge(achievement: achievement)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Achievement Badge

struct AchievementBadge: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? rarityColor.opacity(0.2) : Color(.systemGray5))
                    .frame(width: 60, height: 60)
                
                Image(systemName: achievement.iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(achievement.isUnlocked ? rarityColor : Color.gray)
            }
            
            Text(achievement.title)
                .font(.caption2.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .foregroundStyle(achievement.isUnlocked ? .primary : .secondary)
        }
        .frame(width: 80)
        .opacity(achievement.isUnlocked ? 1 : 0.5)
    }
    
    private var rarityColor: Color {
        switch achievement.rarity {
        case .common: return .gray
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
}

// MARK: - Preview

#Preview {
    ProgressDashboardView()
}
