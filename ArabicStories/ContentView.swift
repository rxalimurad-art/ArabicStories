//
//  ContentView.swift
//  Hikaya
//  Legacy content view - redirects to MainTabView
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Story.self,
            Word.self,
            UserProgress.self
        ], inMemory: true)
}
