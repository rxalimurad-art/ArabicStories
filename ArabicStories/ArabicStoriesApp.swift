//
//  ArabicStoriesApp.swift
//  Arabicly
//  Main app entry point with Firebase configuration
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

@main
struct ArabiclyApp: App {
    
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

#Preview("Root View (Login)") {
    RootView()
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // Do NOT auto-login user - show login screen instead
        // User must explicitly choose to continue as guest or sign in
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Handle Google Sign In callback
        return GIDSignIn.sharedInstance.handle(url)
    }
}
