//
//  MainTabView.swift
//  Hikaya
//  Main tab navigation for the app
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "book.fill")
                }
                .tag(0)
            
            FlashcardsView()
                .tabItem {
                    Label("Flashcards", systemImage: "rectangle.stack.fill")
                }
                .tag(1)
            
            CreateStoryView()
                .tabItem {
                    Label("Create", systemImage: "plus.circle.fill")
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
        .modelContainer(for: [
            Story.self,
            Word.self,
            UserProgress.self
        ], inMemory: true)
}
