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
            RootView()
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @State private var authService = AuthService.shared
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .loadingOverlay(isLoading: authService.isLoading)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // Initialize anonymous auth if no user exists
        // The auth state listener in AuthService will handle the UI updates
        if Auth.auth().currentUser == nil {
            Task {
                do {
                    try await AuthService.shared.signInAnonymously()
                } catch {
                    print("Initial anonymous auth error: \(error)")
                }
            }
        }
        
        return true
    }
}
