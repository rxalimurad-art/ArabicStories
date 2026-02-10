//
//  FlashcardsView.swift
//  Hikaya
//  Flashcards and SRS review system
//

import SwiftUI


struct FlashcardsView: View {
    @State private var viewModel = FlashcardsViewModel()
    @State private var showingSessionSummary = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.hikayaBackground
                    .ignoresSafeArea()
                
                Group {
                    if viewModel.isReviewSessionActive {
                        ReviewSessionView(viewModel: viewModel)
                    } else {
                        FlashcardsDashboardView(viewModel: viewModel)
                    }
                }
            }
            .navigationTitle("Flashcards")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingSessionSummary) {
            if viewModel.sessionComplete {
                SessionSummaryView(viewModel: viewModel)
            }
        }
        .onChange(of: viewModel.sessionComplete) { _, complete in
            showingSessionSummary = complete
        }
    }
}

// MARK: - Flashcards Dashboard View

struct FlashcardsDashboardView: View {
    var viewModel: FlashcardsViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Daily Review Card
                DailyReviewCard(viewModel: viewModel)
                
                // Statistics
                if let stats = viewModel.reviewStats {
                    StatisticsCard(stats: stats)
                }
                
                // Bookmarked Words
                BookmarkedWordsSection(viewModel: viewModel)
            }
            .padding()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}

// MARK: - Daily Review Card

struct DailyReviewCard: View {
    var viewModel: FlashcardsViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Review")
                        .font(.title2.weight(.bold))
                    
                    if let nextReview = viewModel.nextReviewDate {
                        Text("Next review: \(timeUntil(nextReview))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Due Count Badge
                ZStack {
                    Circle()
                        .fill(viewModel.dueTodayCount > 0 ? Color.hikayaOrange : Color.gray)
                        .frame(width: 50, height: 50)
                    
                    Text("\(viewModel.dueTodayCount)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            
            Divider()
            
            // Status
            HStack(spacing: 20) {
                StatusItem(
                    icon: "sparkles",
                    value: "\(viewModel.newWords.count)",
                    label: "New"
                )
                
                StatusItem(
                    icon: "arrow.clockwise",
                    value: "\(viewModel.reviewWords.count)",
                    label: "Review"
                )
                
                StatusItem(
                    icon: "checkmark.circle",
                    value: String(format: "%.0f%%", viewModel.accuracyRate * 100),
                    label: "Accuracy"
                )
            }
            
            // Start Button
            Button {
                Task {
                    await viewModel.startReviewSession()
                }
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text(viewModel.dueTodayCount > 0 ? "Start Review" : "No Cards Due")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.dueTodayCount > 0 ? Color.hikayaTeal : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(viewModel.dueTodayCount == 0)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    private func timeUntil(_ date: Date) -> String {
        let now = Date()
        if date <= now {
            return "now"
        }
        let components = Calendar.current.dateComponents([.hour, .minute], from: now, to: date)
        if let hours = components.hour, hours > 0 {
            return "\(hours)h"
        } else if let minutes = components.minute {
            return "\(minutes)m"
        }
        return "soon"
    }
}

// MARK: - Status Item

struct StatusItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.hikayaTeal)
            
            Text(value)
                .font(.headline.weight(.semibold))
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Statistics Card

struct StatisticsCard: View {
    let stats: ReviewStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Progress")
                .font(.headline)
            
            // Progress Bar
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: geometry.size.width * Double(stats.newWords) / Double(stats.totalWords))
                    Rectangle()
                        .fill(Color.red.opacity(0.6))
                        .frame(width: geometry.size.width * Double(stats.learningWords) / Double(stats.totalWords))
                    Rectangle()
                        .fill(Color.orange.opacity(0.6))
                        .frame(width: geometry.size.width * Double(stats.familiarWords) / Double(stats.totalWords))
                    Rectangle()
                        .fill(Color.green.opacity(0.6))
                        .frame(width: geometry.size.width * Double(stats.masteredWords) / Double(stats.totalWords))
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 8)
            
            // Legend
            HStack(spacing: 12) {
                LegendItem(color: .gray, label: "New", count: stats.newWords)
                LegendItem(color: .red, label: "Learning", count: stats.learningWords)
                LegendItem(color: .orange, label: "Familiar", count: stats.familiarWords)
                LegendItem(color: .green, label: "Mastered", count: stats.masteredWords)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Legend Item

struct LegendItem: View {
    let color: Color
    let label: String
    let count: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(label) \(count)")
                .font(.caption2)
        }
    }
}

// MARK: - Bookmarked Words Section

struct BookmarkedWordsSection: View {
    var viewModel: FlashcardsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Bookmarked Words")
                    .font(.headline)
                
                Spacer()
                
                Text("\(viewModel.bookmarkedWords.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if viewModel.bookmarkedWords.isEmpty {
                Text("No bookmarked words yet. Tap the bookmark icon while reading to save words.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.bookmarkedWords.prefix(5)) { word in
                        BookmarkedWordRow(word: word)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Bookmarked Word Row

struct BookmarkedWordRow: View {
    let word: Word
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(word.arabicText)
                    .font(.title3.weight(.medium))
                
                Text(word.englishMeaning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Mastery indicator
            Circle()
                .fill(masteryColor)
                .frame(width: 10, height: 10)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var masteryColor: Color {
        switch word.masteryLevel {
        case .new: return .gray
        case .learning: return .red
        case .familiar: return .orange
        case .mastered: return .blue
        case .known: return .green
        }
    }
}

// MARK: - Review Session View

struct ReviewSessionView: View {
    var viewModel: FlashcardsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress Bar
            ProgressView(value: viewModel.sessionProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .hikayaTeal))
                .padding()
            
            // Card
            if let word = viewModel.currentWord {
                FlashcardView(
                    word: word,
                    isFlipped: viewModel.isFlipped,
                    onFlip: { viewModel.flipCard() }
                )
                .padding()
                
                Spacer()
                
                // Response Buttons
                if viewModel.isFlipped {
                    ResponseButtons { response in
                        Task {
                            await viewModel.submitReview(response)
                        }
                    }
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Text("Tap card to reveal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
        }
    }
}

// MARK: - Flashcard View

struct FlashcardView: View {
    let word: Word
    let isFlipped: Bool
    let onFlip: () -> Void
    
    var body: some View {
        ZStack {
            // Front (Arabic)
            CardFace(
                content: {
                    VStack(spacing: 20) {
                        Text(word.displayText)
                            .font(.custom("NotoNaskhArabic", size: 64))
                            .fontWeight(.bold)
                        
                        if let tashkeel = word.tashkeel {
                            Text(tashkeel)
                                .font(.custom("NotoNaskhArabic", size: 32))
                                .foregroundStyle(.secondary)
                        }
                    }
                },
                color: .white
            )
            .opacity(isFlipped ? 0 : 1)
            .rotation3DEffect(
                .degrees(isFlipped ? 180 : 0),
                axis: (x: 0, y: 1, z: 0)
            )
            
            // Back (English + Details)
            CardFace(
                content: {
                    VStack(spacing: 16) {
                        Text(word.englishMeaning)
                            .font(.title.weight(.semibold))
                            .multilineTextAlignment(.center)
                        
                        Text(word.transliteration)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .italic()
                        
                        HStack(spacing: 8) {
                            Label(word.partOfSpeech.displayName, systemImage: word.partOfSpeech.icon)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.hikayaTeal.opacity(0.15))
                                .foregroundStyle(Color.hikayaTeal)
                                .clipShape(Capsule())
                        }
                        
                        if let root = word.rootLetters {
                            Text("Root: \(root)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                },
                color: Color.hikayaCream
            )
            .opacity(isFlipped ? 1 : 0)
            .rotation3DEffect(
                .degrees(isFlipped ? 0 : -180),
                axis: (x: 0, y: 1, z: 0)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: 400)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                onFlip()
            }
        }
    }
}

// MARK: - Card Face

struct CardFace<Content: View>: View {
    let content: Content
    let color: Color
    
    init(@ViewBuilder content: () -> Content, color: Color) {
        self.content = content()
        self.color = color
    }
    
    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Response Buttons

struct ResponseButtons: View {
    let onResponse: (ResponseQuality) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ResponseButton(
                    quality: .again,
                    color: .red,
                    interval: "<1m"
                ) { onResponse(.again) }
                
                ResponseButton(
                    quality: .hard,
                    color: .orange,
                    interval: "2d"
                ) { onResponse(.hard) }
            }
            
            HStack(spacing: 12) {
                ResponseButton(
                    quality: .good,
                    color: .blue,
                    interval: "4d"
                ) { onResponse(.good) }
                
                ResponseButton(
                    quality: .easy,
                    color: .green,
                    interval: "7d"
                ) { onResponse(.easy) }
            }
        }
    }
}

// MARK: - Response Button

struct ResponseButton: View {
    let quality: ResponseQuality
    let color: Color
    let interval: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(quality.displayName)
                    .font(.headline.weight(.semibold))
                Text(interval)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Session Summary View

struct SessionSummaryView: View {
    var viewModel: FlashcardsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Success Animation
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
                
                Text("Session Complete!")
                    .font(.title.weight(.bold))
                
                // Stats
                VStack(spacing: 16) {
                    SummaryStatRow(
                        icon: "xmark.circle.fill",
                        label: "Again",
                        count: viewModel.againCount,
                        color: .red
                    )
                    
                    SummaryStatRow(
                        icon: "exclamationmark.circle.fill",
                        label: "Hard",
                        count: viewModel.hardCount,
                        color: .orange
                    )
                    
                    SummaryStatRow(
                        icon: "checkmark.circle.fill",
                        label: "Good",
                        count: viewModel.goodCount,
                        color: .blue
                    )
                    
                    SummaryStatRow(
                        icon: "star.circle.fill",
                        label: "Easy",
                        count: viewModel.easyCount,
                        color: .green
                    )
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Accuracy
                Text("Accuracy: \(Int(viewModel.accuracyRate * 100))%")
                    .font(.headline)
                    .foregroundStyle(viewModel.accuracyRate > 0.7 ? .green : .orange)
                
                Spacer()
                
                Button("Done") {
                    viewModel.endSession()
                    dismiss()
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.hikayaTeal)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Summary Stat Row

struct SummaryStatRow: View {
    let icon: String
    let label: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
            
            Text(label)
                .font(.subheadline)
            
            Spacer()
            
            Text("\(count)")
                .font(.headline.weight(.semibold))
        }
    }
}

// MARK: - Preview

#Preview {
    FlashcardsView()
}
