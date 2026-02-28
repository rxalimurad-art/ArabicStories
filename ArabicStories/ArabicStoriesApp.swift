//
//  ArabicStoriesApp.swift
//  Arabicly
//  Main app entry point with Firebase configuration
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import UserNotifications

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

        // Register default values — reminders on by default
        UserDefaults.standard.register(defaults: [
            "morningReminder": true,
            "afternoonReminder": true
        ])

        // Request notification permission at app launch
        requestNotificationPermission()
        
        return true
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            } else {
                print("Notification permission granted: \(granted)")
                if granted {
                    self.scheduleDefaultNotifications()
                }
            }
        }
    }

    private func scheduleDefaultNotifications() {
        let center = UNUserNotificationCenter.current()
        let defaults = UserDefaults.standard

        if defaults.bool(forKey: "morningReminder") {
            let content = UNMutableNotificationContent()
            content.title = "Time to Learn Arabic! 🌅"
            content.body = "Start your day with a quick Arabic story. Keep your streak going!"
            content.sound = .default
            var components = DateComponents()
            components.hour = 9
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            center.add(UNNotificationRequest(identifier: "morning-reminder", content: content, trigger: trigger))
        }

        if defaults.bool(forKey: "afternoonReminder") {
            let content = UNMutableNotificationContent()
            content.title = "Continue Your Arabic Journey! ☀️"
            content.body = "Take a break and practice your Arabic vocabulary."
            content.sound = .default
            var components = DateComponents()
            components.hour = 15
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            center.add(UNNotificationRequest(identifier: "afternoon-reminder", content: content, trigger: trigger))
        }
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Handle Google Sign In callback
        return GIDSignIn.sharedInstance.handle(url)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let achievementUnlocked = Notification.Name("achievementUnlocked")
}
