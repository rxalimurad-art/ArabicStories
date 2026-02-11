//
//  MainTabView.swift
//  Hikaya
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
            
            WordQuizView()
                .tabItem {
                    Label("Quiz", systemImage: "checkmark.circle.fill")
                }
                .tag(1)
            
            ProgressDashboardView()
                .tabItem {
                    Label("Progress", systemImage: "chart.bar.fill")
                }
                .tag(2)
            
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
