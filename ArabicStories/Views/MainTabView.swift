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
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "book.fill")
                }
                .tag(0)
            
            WordsListView()
                .tabItem {
                    Label("Words", systemImage: "textformat.abc")
                }
                .tag(1)
            
            WordQuizView()
                .tabItem {
                    Label("Quiz", systemImage: "checkmark.circle.fill")
                }
                .tag(2)
            
            ProgressDashboardView()
                .tabItem {
                    Label("Progress", systemImage: "chart.bar.fill")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .tint(.hikayaTeal)
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
}
