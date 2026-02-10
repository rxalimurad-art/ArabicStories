//
//  ArabicStoriesApp.swift
//  Hikaya
//  Main app entry point with Firebase configuration
//

import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct HikayaApp: App {
    
    // Register app delegate for Firebase
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // Anonymous auth for user data
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously { authResult, error in
                if let error = error {
                    print("Auth error: \(error)")
                }
            }
        }
        
        return true
    }
}
