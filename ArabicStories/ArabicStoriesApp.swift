//
//  ArabicStoriesApp.swift
//  Hikaya
//  Main app entry point with Firebase configuration
//

import SwiftUI
import FirebaseCore

@main
struct HikayaApp: App {
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
