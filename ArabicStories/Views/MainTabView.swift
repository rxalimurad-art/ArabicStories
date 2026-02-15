//
//  MainTabView.swift
//  Arabicly
//  Main tab navigation for the app
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var unlockedAchievement: Achievement?
    @State private var showAchievementUnlocked = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Learn - Stories for reading
            LibraryView()
                .tabItem {
                    Label("Learn", systemImage: "book.fill")
                }
                .tag(0)
            
            // Tab 2: Words - My Words (from stories) + All Words (reference)
            WordsTabView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Words", systemImage: "text.book.closed")
                }
                .tag(1)
            
            // Tab 3: Progress - Stats, streaks, Quran completion
            ProgressDashboardView()
                .tabItem {
                    Label("Progress", systemImage: "chart.bar.fill")
                }
                .tag(2)
            
            // Tab 4: Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .tint(.hikayaTeal)
        .onReceive(NotificationCenter.default.publisher(for: .achievementUnlocked)) { notification in
            print("📖 Complete story: MainTabView received achievement notification")
            if let achievement = notification.object as? Achievement {
                print("📖 Complete story: Setting achievement - \(achievement.title)")
                unlockedAchievement = achievement
                showAchievementUnlocked = true
                print("📖 Complete story: showAchievementUnlocked set to true")
            } else {
                print("📖 Complete story: ERROR - No achievement in notification")
            }
        }
        .sheet(isPresented: $showAchievementUnlocked, onDismiss: {
            print("📖 Complete story: Achievement sheet dismissed")
            showAchievementUnlocked = false
            unlockedAchievement = nil
        }) {
            AchievementSheetContent(
                achievement: unlockedAchievement,
                onDismiss: {
                    showAchievementUnlocked = false
                    unlockedAchievement = nil
                }
            )
        }
    }
}

// MARK: - Achievement Sheet Content

struct AchievementSheetContent: View {
    let achievement: Achievement?
    let onDismiss: () -> Void
    
    init(achievement: Achievement?, onDismiss: @escaping () -> Void) {
        self.achievement = achievement
        self.onDismiss = onDismiss
        if let ach = achievement {
            print("📖 Complete story: Showing AchievementUnlockedView for \(ach.title)")
        } else {
            print("📖 Complete story: ERROR - No achievement when presenting sheet!")
        }
    }
    
    var body: some View {
        if let achievement = achievement {
            AchievementUnlockedView(achievement: achievement) {
                print("📖 Complete story: Achievement view dismiss callback")
                onDismiss()
            }
        } else {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)
                Text("Error loading achievement")
                    .font(.headline)
            }
            .padding()
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
}
