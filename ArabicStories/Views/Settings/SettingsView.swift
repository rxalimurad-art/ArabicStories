//
//  SettingsView.swift
//  Arabicly
//  App settings and preferences
//

import SwiftUI
import FirebaseAuth

@Observable
class NotificationSettings {
    static let shared = NotificationSettings()
    
    var morningReminder: Bool {
        get { UserDefaults.standard.bool(forKey: "morningReminder") }
        set { UserDefaults.standard.set(newValue, forKey: "morningReminder") }
    }
    
    var afternoonReminder: Bool {
        get { UserDefaults.standard.bool(forKey: "afternoonReminder") }
        set { UserDefaults.standard.set(newValue, forKey: "afternoonReminder") }
    }
    
    private init() {}
}

struct SettingsView: View {
    @State private var authService = AuthService.shared
    @State private var showingResetAlert = false
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAlert = false
    @State private var showingAccountLinking = false
    @State private var morningReminder = NotificationSettings.shared.morningReminder
    @State private var afternoonReminder = NotificationSettings.shared.afternoonReminder
    @State private var showingNotificationAlert = true
    @State private var dailyGoalMinutes = 5
    @State private var dataService = DataService.shared
    
    var body: some View {
        NavigationStack {
            List {
                // Account Section
                accountSection
                
                // Daily Goal
                Section {
                    VStack(alignment: .center, spacing: 16) {
                        // Icon and Title
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.hikayaOrange.opacity(0.15))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Color.hikayaOrange)
                            }
                            
                            Text("Daily Study Goal")
                                .font(.headline)
                            
                            Text("Commit to learning Arabic every day")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Minutes Display
                        VStack(spacing: 4) {
                            Text("\(dailyGoalMinutes)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hikayaOrange)
                            
                            Text("minutes")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Slider
                        VStack(spacing: 8) {
                            Slider(
                                value: Binding(
                                    get: { Double(dailyGoalMinutes) },
                                    set: { newValue in
                                        // Snap to nearest 5
                                        let snapped = Int(round(newValue / 5) * 5)
                                        dailyGoalMinutes = max(5, min(60, snapped))
                                    }
                                ),
                                in: 5...60,
                                step: 5
                            )
                            .tint(Color.hikayaOrange)
                            
                            // Labels
                            HStack {
                                Text("5 min")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("30 min")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("60 min")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        // Preset buttons
                        HStack(spacing: 8) {
                            ForEach([5, 10, 15, 20, 30], id: \.self) { minutes in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        dailyGoalMinutes = minutes
                                    }
                                    Task {
                                        await updateDailyGoal(minutes: minutes)
                                    }
                                } label: {
                                    Text("\(minutes)m")
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(dailyGoalMinutes == minutes ? Color.hikayaOrange : Color(.systemGray5))
                                        )
                                        .foregroundStyle(dailyGoalMinutes == minutes ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
                .onAppear {
                    // Load current daily goal
                    Task {
                        if let progress = await dataService.fetchUserProgress() {
                            await MainActor.run {
                                dailyGoalMinutes = progress.dailyGoalMinutes
                            }
                        }
                    }
                }
                .onChange(of: dailyGoalMinutes) { _, newValue in
                    Task {
                        await updateDailyGoal(minutes: newValue)
                    }
                }
                
                // Notifications
                Section("Reminders") {
                    Toggle(isOn: $morningReminder) {
                        HStack {
                            Image(systemName: "sunrise.fill")
                                .frame(width: 30)
                                .foregroundStyle(Color.orange)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Morning Reminder")
                                Text("9:00 AM")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onChange(of: morningReminder) { _, newValue in
                        handleNotificationToggle(newValue)
                    }
                    
                    Toggle(isOn: $afternoonReminder) {
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .frame(width: 30)
                                .foregroundStyle(Color.hikayaOrange)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Afternoon Reminder")
                                Text("3:00 PM")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onChange(of: afternoonReminder) { _, newValue in
                        handleNotificationToggle(newValue)
                    }
                }
                
                // Data Management
                Section("Data Management") {
                    Button {
                        showingResetAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .frame(width: 30)
                                .foregroundStyle(.red)
                            
                            Text("Reset All Progress")
                                .foregroundStyle(.red)
                        }
                    }
                }
                
                // About
                Section("About") {
                    HStack {
                        Image(systemName: "info.circle")
                            .frame(width: 30)
                            .foregroundStyle(Color.hikayaTeal)
                        
                        Text("Version")
                        
                        Spacer()
                        
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "mailto:volutiontechnologies@gmail.com")!) {
                        HStack {
                            Image(systemName: "envelope")
                                .frame(width: 30)
                                .foregroundStyle(Color.hikayaTeal)
                            
                            Text("Contact Us")
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Acknowledgments
                Section {
                    Text("Arabicly helps you learn Arabic through stories. Built with love by Volution Technologies.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Sign Out & Delete Account (bottom)
                destructiveActionsSection
            }
            .navigationTitle("Settings")
            .alert("Reset Progress?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    resetAllProgress()
                }
            } message: {
                Text("This will reset all your reading progress, word statistics, and achievements. This action cannot be undone.")
            }
            .alert("Enable Notifications?", isPresented: $showingNotificationAlert) {
                Button("Cancel", role: .cancel) {
                    morningReminder = false
                    afternoonReminder = false
                }
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("Please enable notifications in Settings to receive study reminders.")
            }
            .sheet(isPresented: $showingAccountLinking) {
                AccountLinkingView()
            }
            .alert("Sign Out?", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
            } message: {
                Text("Your data is safely stored. You can sign back in anytime.")
            }
            .alert("Delete Account?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("This will permanently delete your account and all associated data. This action cannot be undone.")
            }
        }
    }
    
    private func handleNotificationToggle(_ enabled: Bool) {
        // Save to UserDefaults
        NotificationSettings.shared.morningReminder = morningReminder
        NotificationSettings.shared.afternoonReminder = afternoonReminder
        
        if enabled {
            requestNotificationPermission()
        } else {
            // If both are disabled, we could optionally cancel scheduled notifications
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if !granted {
                    showingNotificationAlert = true
                } else {
                    scheduleNotifications()
                }
            }
        }
    }
    
    private func scheduleNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        // Morning reminder at 9:00 AM
        if morningReminder {
            let morningContent = UNMutableNotificationContent()
            morningContent.title = "Time to Learn Arabic! 🌅"
            morningContent.body = "Start your day with a quick Arabic story. Keep your streak going!"
            morningContent.sound = .default
            
            var morningDate = DateComponents()
            morningDate.hour = 9
            morningDate.minute = 0
            let morningTrigger = UNCalendarNotificationTrigger(dateMatching: morningDate, repeats: true)
            let morningRequest = UNNotificationRequest(identifier: "morning-reminder", content: morningContent, trigger: morningTrigger)
            center.add(morningRequest)
        }
        
        // Afternoon reminder at 3:00 PM
        if afternoonReminder {
            let afternoonContent = UNMutableNotificationContent()
            afternoonContent.title = "Continue Your Arabic Journey! ☀️"
            afternoonContent.body = "Take a break and practice your Arabic vocabulary."
            afternoonContent.sound = .default
            
            var afternoonDate = DateComponents()
            afternoonDate.hour = 15
            afternoonDate.minute = 0
            let afternoonTrigger = UNCalendarNotificationTrigger(dateMatching: afternoonDate, repeats: true)
            let afternoonRequest = UNNotificationRequest(identifier: "afternoon-reminder", content: afternoonContent, trigger: afternoonTrigger)
            center.add(afternoonRequest)
        }
    }
    
    private func signOut() {
        Task {
            do {
                try await authService.signOut()
            } catch {
                print("Error signing out: \(error.localizedDescription)")
            }
        }
    }
    
    private func deleteAccount() {
        Task {
            do {
                try await authService.deleteAccount()
            } catch {
                print("Error deleting account: \(error.localizedDescription)")
            }
        }
    }
    
    private func resetAllProgress() {
        // Implementation for resetting all progress
    }
    
    private func updateDailyGoal(minutes: Int) async {
        guard var progress = await dataService.fetchUserProgress() else { return }
        progress.dailyGoalMinutes = minutes
        try? await dataService.updateUserProgress(progress)
        print("✅ Updated daily goal to \(minutes) minutes")
    }
    
    // MARK: - Account Section (user info + connect only)
    private var accountSection: some View {
        Section("Account") {
            // User info
            HStack {
                Image(systemName: authService.isAnonymous ? "person.fill.questionmark" : "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(authService.isAnonymous ? .secondary : Color.hikayaTeal)

                VStack(alignment: .leading, spacing: 4) {
                    Text(authService.currentUser?.displayName ?? "Guest User")
                        .font(.headline)

                    Text(authService.isAnonymous ? "Guest Account" : (authService.currentUser?.email ?? "Connected Account"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            // Connect Account option (only for anonymous users)
            if authService.isAnonymous {
                Button {
                    showingAccountLinking = true
                } label: {
                    HStack {
                        Image(systemName: "link.circle.fill")
                            .frame(width: 30)
                            .foregroundStyle(Color.hikayaOrange)

                        Text("Connect Account")
                            .foregroundStyle(Color.hikayaDeepTeal)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Destructive Actions Section (at bottom)
    private var destructiveActionsSection: some View {
        Section {
            // Sign Out
            Button {
                showingSignOutAlert = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .frame(width: 30)
                        .foregroundStyle(.secondary)

                    Text("Sign Out")
                        .foregroundStyle(.primary)
                }
            }

            // Delete Account
            Button {
                showingDeleteAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .frame(width: 30)
                        .foregroundStyle(.red)

                    Text("Delete Account")
                        .foregroundStyle(.red)
                }
            }
        } footer: {
            Text("Signing out will keep your data safe. Deleting your account will permanently remove all your data.")
                .font(.caption)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
