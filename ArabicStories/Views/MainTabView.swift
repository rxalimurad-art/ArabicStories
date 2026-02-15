//
//  MainTabView.swift
//  Arabicly
//  Main tab navigation for the app
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
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
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
}
