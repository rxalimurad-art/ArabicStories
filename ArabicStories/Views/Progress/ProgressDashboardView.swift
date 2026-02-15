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
                        // Streak Card
                        StreakCard(viewModel: viewModel)
                        
                        // Daily Goal Card
                        DailyGoalCard(viewModel: viewModel)
                        
                        // Quick Stats Grid
                        QuickStatsGrid(viewModel: viewModel)
                        
                        // Weekly Progress Chart
                        WeeklyProgressCard(viewModel: viewModel)
                        
                        // Achievements Section
                        AchievementsSection(viewModel: viewModel)
                    }
                    .padding()
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $viewModel.showAchievementUnlocked) {
                if let achievement = viewModel.newlyUnlockedAchievement {
                    AchievementUnlockedView(achievement: achievement) {
                        viewModel.acknowledgeAchievement()
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .onAppear {
                // Refresh data when view appears to show latest reading time
                Task {
                    await viewModel.loadUserProgress()
                }
            }
        }
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


// MARK: - Achievements Section

struct AchievementsSection: View {
    var viewModel: ProgressViewModel
    @State private var showingAllAchievements = false
    
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
            
            // See All Button
            Button {
                showingAllAchievements = true
            } label: {
                HStack {
                    Text("See All Achievements")
                        .font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundStyle(Color.hikayaTeal)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        .sheet(isPresented: $showingAllAchievements) {
            AchievementsListView(achievements: viewModel.achievements)
        }
    }
}

// MARK: - Achievement Badge

struct AchievementBadge: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? categoryColor.opacity(0.2) : Color(.systemGray5))
                    .frame(width: 60, height: 60)
                
                Image(systemName: achievement.iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(achievement.isUnlocked ? categoryColor : Color.gray)
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
    
    /// Category-based colors for better visual distinction
    private var categoryColor: Color {
        switch achievement.category {
        case .streak:
            return Color.orange  // Fire/streak = orange
        case .vocabulary:
            return Color.green   // Growth/words = green
        case .stories:
            return Color.blue    // Books/stories = blue
        case .time:
            return Color.cyan    // Time = cyan
        case .mastery:
            return Color.purple  // Mastery/skill = purple
        case .social:
            return Color.pink    // Social = pink
        @unknown default:
            return Color.gray
        }
    }
}

// MARK: - Daily Goal Card

struct DailyGoalCard: View {
    var viewModel: ProgressViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Goal")
                        .font(.headline.weight(.semibold))
                    
                    Text(viewModel.isDailyGoalCompleted 
                        ? "🎉 Goal completed! Great job!" 
                        : "\(viewModel.dailyGoalMinutes - viewModel.todayStudyMinutes) min to reach goal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.hikayaOrange.opacity(0.2), lineWidth: 6)
                        .frame(width: 56, height: 56)
                    
                    Circle()
                        .trim(from: 0, to: viewModel.dailyGoalProgress)
                        .stroke(
                            Color.hikayaOrange,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: viewModel.isDailyGoalCompleted ? "checkmark" : "flame.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(viewModel.isDailyGoalCompleted ? .green : Color.hikayaOrange)
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
                                colors: [Color.hikayaOrange, Color.hikayaOrange.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * viewModel.dailyGoalProgress, height: 12)
                }
            }
            .frame(height: 12)
            
            HStack {
                Text("\(viewModel.todayStudyMinutes) min today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("Goal: \(viewModel.dailyGoalMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Achievement Unlocked View

struct AchievementUnlockedView: View {
    let achievement: Achievement
    let onDismiss: () -> Void
    @State private var showConfetti = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon with category color
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: achievement.iconName)
                    .font(.system(size: 60))
                    .foregroundStyle(categoryColor)
            }
            
            // Text
            VStack(spacing: 8) {
                Text("Achievement Unlocked!")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                
                Text(achievement.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(categoryColor)
                
                Text(achievement.achievementDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                // Category & Rarity badges
                HStack(spacing: 12) {
                    Text(achievement.category.displayName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(categoryColor.opacity(0.2))
                        .foregroundStyle(categoryColor)
                        .clipShape(Capsule())
                    
                    Text(achievement.rarity.displayName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(rarityBadgeColor.opacity(0.2))
                        .foregroundStyle(rarityBadgeColor)
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
            
            // Dismiss button with category color
            Button(action: onDismiss) {
                Text("Awesome!")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(categoryColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .background(Color.hikayaBackground)
    }
    
    /// Category-based colors for visual distinction
    private var categoryColor: Color {
        switch achievement.category {
        case .streak:
            return Color.orange  // Fire/streak = orange
        case .vocabulary:
            return Color.green   // Growth/words = green
        case .stories:
            return Color.blue    // Books/stories = blue
        case .time:
            return Color.cyan    // Time = cyan
        case .mastery:
            return Color.purple  // Mastery/skill = purple
        case .social:
            return Color.pink    // Social = pink
        @unknown default:
            return Color.gray
        }
    }
    
    /// Rarity badge colors
    private var rarityBadgeColor: Color {
        switch achievement.rarity {
        case .common: return .gray
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        @unknown default:
            return .gray
        }
    }
}

// MARK: - Achievements List View

struct AchievementsListView: View {
    let achievements: [Achievement]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Summary Section
                Section {
                    AchievementsSummaryView(achievements: achievements)
                }
                
                // Unlocked Achievements
                if !unlockedAchievements.isEmpty {
                    Section("Unlocked") {
                        ForEach(unlockedAchievements) { achievement in
                            AchievementRow(achievement: achievement)
                        }
                    }
                }
                
                // Locked Achievements
                if !lockedAchievements.isEmpty {
                    Section("Locked") {
                        ForEach(lockedAchievements) { achievement in
                            AchievementRow(achievement: achievement)
                        }
                    }
                }
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var unlockedAchievements: [Achievement] {
        achievements.filter { $0.isUnlocked }.sorted { $0.rarity.rawValue > $1.rarity.rawValue }
    }
    
    private var lockedAchievements: [Achievement] {
        achievements.filter { !$0.isUnlocked }
    }
}

// MARK: - Achievements Summary View

struct AchievementsSummaryView: View {
    let achievements: [Achievement]
    
    var unlockedCount: Int {
        achievements.filter { $0.isUnlocked }.count
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.hikayaOrange,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Text("\(unlockedCount)")
                        .font(.title.bold())
                    Text("of \(achievements.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text("\(Int(progress * 100))% Complete")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private var progress: Double {
        guard achievements.count > 0 else { return 0 }
        return Double(unlockedCount) / Double(achievements.count)
    }
}

// MARK: - Achievement Row

struct AchievementRow: View {
    let achievement: Achievement
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? categoryColor.opacity(0.2) : Color(.systemGray5))
                    .frame(width: 50, height: 50)
                
                Image(systemName: achievement.iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(achievement.isUnlocked ? categoryColor : Color.gray)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(achievement.title)
                        .font(.subheadline.weight(.semibold))
                    
                    if achievement.isUnlocked {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                
                Text(achievement.achievementDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                // Category tag
                HStack(spacing: 8) {
                    Text(achievement.category.displayName)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(categoryColor.opacity(0.15))
                        .foregroundStyle(categoryColor)
                        .clipShape(Capsule())
                    
                    // Progress for locked achievements
                    if !achievement.isUnlocked {
                        Text("\(achievement.currentProgress)/\(achievement.requirement)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Progress bar for locked achievements
                if !achievement.isUnlocked {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(.systemGray5))
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(categoryColor)
                                .frame(width: geometry.size.width * achievement.progressPercentage, height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.top, 4)
                }
            }
            
            Spacer()
            
            // Rarity Badge
            Text(achievement.rarity.displayName)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(rarityBadgeColor.opacity(0.15))
                .foregroundStyle(rarityBadgeColor)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
        .opacity(achievement.isUnlocked ? 1 : 0.6)
    }
    
    /// Category-based colors for visual distinction
    private var categoryColor: Color {
        switch achievement.category {
        case .streak:
            return Color.orange  // Fire/streak = orange
        case .vocabulary:
            return Color.green   // Growth/words = green
        case .stories:
            return Color.blue    // Books/stories = blue
        case .time:
            return Color.cyan    // Time = cyan
        case .mastery:
            return Color.purple  // Mastery/skill = purple
        case .social:
            return Color.pink    // Social = pink
        @unknown default:
            return Color.gray
        }
    }
    
    /// Rarity badge colors
    private var rarityBadgeColor: Color {
        switch achievement.rarity {
        case .common: return .gray
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        @unknown default:
            return .gray
        }
    }
    
    private var rarityColor: Color {
        switch achievement.rarity {
        case .common: return .gray
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        @unknown default:
            return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    ProgressDashboardView()
}
