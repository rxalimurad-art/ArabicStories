//
//  SettingsView.swift
//  Hikaya
//  App settings and preferences
//

import SwiftUI

struct SettingsView: View {
    @State private var showingResetAlert = false
    @State private var dailyGoalMinutes = 15
    @State private var notificationsEnabled = true
    @State private var autoPlayAudio = true
    @State private var showTransliteration = true
    
    var body: some View {
        NavigationStack {
            List {
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
                    Text("Hikaya uses the SM-2 algorithm for spaced repetition. Arabic text rendered with Noto Naskh Arabic.")
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
        }
    }
    
    private func resetAllProgress() {
        // Implementation for resetting all progress
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
