//
//  SettingsView.swift
//  Arabicly
//  App settings and preferences
//

import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @State private var authService = AuthService.shared
    @State private var showingResetAlert = false
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAlert = false
    @State private var showingAccountLinking = false
    @State private var dailyGoalMinutes = 15
    @State private var notificationsEnabled = true
    @State private var autoPlayAudio = true
    @State private var showTransliteration = true
    
    var body: some View {
        NavigationStack {
            List {
                // Account Section
                accountSection
                
                // Study Settings
                Section("Study Settings") {
                    NavigationLink {
                        DailyGoalSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "target")
                                .frame(width: 30)
                                .foregroundStyle(Color.hikayaTeal)
                            
                            Text("Daily Goal")
                            
                            Spacer()
                            
                            Text("\(dailyGoalMinutes) min")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Toggle(isOn: $notificationsEnabled) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .frame(width: 30)
                                .foregroundStyle(Color.hikayaOrange)
                            
                            Text("Daily Reminders")
                        }
                    }
                }
                
                // Reader Settings
                Section("Reader Preferences") {
                    Toggle(isOn: $autoPlayAudio) {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                                .frame(width: 30)
                                .foregroundStyle(Color.hikayaTeal)
                            
                            Text("Auto-play Audio")
                        }
                    }
                    
                    Toggle(isOn: $showTransliteration) {
                        HStack {
                            Image(systemName: "character.phonetic")
                                .frame(width: 30)
                                .foregroundStyle(Color.hikayaTeal)
                            
                            Text("Show Transliteration")
                        }
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
                    
                    Link(destination: URL(string: "https://hikaya.app")!) {
                        HStack {
                            Image(systemName: "globe")
                                .frame(width: 30)
                                .foregroundStyle(Color.hikayaTeal)
                            
                            Text("Website")
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "mailto:support@hikaya.app")!) {
                        HStack {
                            Image(systemName: "envelope")
                                .frame(width: 30)
                                .foregroundStyle(Color.hikayaTeal)
                            
                            Text("Contact Support")
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Acknowledgments
                Section {
                    Text("Arabicly uses the SM-2 algorithm for spaced repetition. Arabic text rendered with Noto Naskh Arabic.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
    
    private func signOut() {
        do {
            try authService.signOut()
        } catch {
            print("Error signing out: \(error.localizedDescription)")
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
    
    // MARK: - Account Section
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
            
            // Sign Out
            Button {
                showingSignOutAlert = true
            } label: {
                HStack {
                    Image(systemName: "arrow.left.circle.fill")
                        .frame(width: 30)
                        .foregroundStyle(.orange)
                    
                    Text("Sign Out")
                        .foregroundStyle(.primary)
                }
            }
            
            // Delete Account
            Button {
                showingDeleteAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash.circle.fill")
                        .frame(width: 30)
                        .foregroundStyle(.red)
                    
                    Text("Delete Account")
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

// MARK: - Daily Goal Settings View

struct DailyGoalSettingsView: View {
    @State private var goalMinutes = 15
    @Environment(\.dismiss) private var dismiss
    
    let options = [10, 15, 20, 30, 45, 60]
    
    var body: some View {
        List {
            Section("Select your daily study goal") {
                ForEach(options, id: \.self) { minutes in
                    Button {
                        goalMinutes = minutes
                    } label: {
                        HStack {
                            Text("\(minutes) minutes")
                            
                            Spacer()
                            
                            if goalMinutes == minutes {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.hikayaTeal)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            
            Section {
                Button("Save") {
                    // Save the goal
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(Color.hikayaTeal)
            }
        }
        .navigationTitle("Daily Goal")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
