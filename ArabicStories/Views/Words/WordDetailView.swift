//
//  WordDetailView.swift
//  Hikaya
//  Word detail view with full information
//

import SwiftUI

struct WordDetailView: View {
    let word: Word
    let stat: WordStat?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Word Header Card
                    wordHeaderCard
                    
                    // Stats Section
                    if let stat = stat {
                        statsSection(stat)
                    }
                    
                    // Word Details
                    detailsSection
                    
                    // Example Sentences
                    if let examples = word.exampleSentences, !examples.isEmpty {
                        examplesSection(examples)
                    }
                    
                    // SRS Info
                    srsSection
                }
                .padding()
            }
            .navigationTitle("Word Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .background(Color.hikayaCream.ignoresSafeArea())
        }
    }
    
    // MARK: - Word Header Card
    
    private var wordHeaderCard: some View {
        VStack(spacing: 16) {
            // Arabic Word (Large)
            Text(word.arabicText)
                .font(.custom("NotoNaskhArabic", size: 56))
                .multilineTextAlignment(.center)
            
            // Transliteration
            if let transliteration = word.transliteration {
                Text(transliteration)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            
            // English Meaning
            Text(word.englishMeaning)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            
            // Action Buttons
            HStack(spacing: 20) {
                ActionButton(
                    icon: "speaker.wave.2.fill",
                    title: "Listen",
                    color: .hikayaTeal
                ) {
                    // Play pronunciation
                    Task {
                        await PronunciationService.shared.playPronunciation(for: word)
                    }
                }
                
                ActionButton(
                    icon: word.isBookmarked == true ? "bookmark.fill" : "bookmark",
                    title: word.isBookmarked == true ? "Saved" : "Save",
                    color: word.isBookmarked == true ? .hikayaOrange : .gray
                ) {
                    // Toggle bookmark
                }
                
                ActionButton(
                    icon: "rectangle.stack.badge.plus",
                    title: "Add to Quiz",
                    color: .blue
                ) {
                    // Add to quiz
                }
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 5)
        )
    }
    
    // MARK: - Stats Section
    
    private func statsSection(_ stat: WordStat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Learning Stats")
                .font(.headline)
            
            HStack(spacing: 16) {
                StatBox(
                    title: "Mastery",
                    value: "\(stat.masteryPercentage)%",
                    color: masteryColor(stat.masteryPercentage)
                )
                
                StatBox(
                    title: "Reviews",
                    value: "\(stat.timesReviewed)",
                    color: .blue
                )
                
                StatBox(
                    title: "Correct",
                    value: "\(stat.timesCorrect)",
                    color: .green
                )
            }
            
            // Progress Bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Mastery Progress")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if stat.isMastered {
                        Label("Mastered", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                    }
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(masteryColor(stat.masteryPercentage))
                            .frame(width: geo.size.width * CGFloat(stat.masteryPercentage) / 100, height: 8)
                    }
                }
                .frame(height: 8)
            }
            
            if let lastReviewed = stat.lastReviewed {
                HStack {
                    Text("Last reviewed:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(lastReviewed, style: .relative)
                        .font(.caption.weight(.medium))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 10)
        )
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Word Details")
                .font(.headline)
            
            VStack(spacing: 12) {
                DetailRow(icon: "textformat", title: "Part of Speech", value: word.partOfSpeech?.displayName ?? "Not specified")
                
                if let rootLetters = word.rootLetters {
                    DetailRow(icon: "link", title: "Root Letters", value: rootLetters)
                }
                
                DetailRow(icon: "star.fill", title: "Difficulty", value: "Level \(word.difficulty)")
                
                if let tashkeel = word.tashkeel {
                    DetailRow(icon: "sparkles", title: "With Tashkeel", value: tashkeel)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 10)
        )
    }
    
    // MARK: - Examples Section
    
    private func examplesSection(_ examples: [ExampleSentence]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Example Sentences")
                .font(.headline)
            
            VStack(spacing: 12) {
                ForEach(examples) { sentence in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(sentence.arabic)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(sentence.transliteration)
                            .font(.caption)
                            .italic()
                            .foregroundStyle(.secondary)
                        
                        Text(sentence.english)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.hikayaCream.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 10)
        )
    }
    
    // MARK: - SRS Section
    
    private var srsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spaced Repetition")
                .font(.headline)
            
            HStack(spacing: 12) {
                SRSStatCard(
                    title: "Mastery Level",
                    value: word.masteryLevel?.displayName ?? "New",
                    color: masteryLevelColor(word.masteryLevel)
                )
                
                SRSStatCard(
                    title: "Next Review",
                    value: word.nextReviewDate != nil ? timeUntil(word.nextReviewDate!) : "Now",
                    color: word.nextReviewDate.map { $0 <= Date() ? .red : .blue } ?? .gray
                )
            }
            
            if let reviewCount = word.reviewCount, reviewCount > 0 {
                HStack {
                    Text("Reviewed \(reviewCount) times")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if let easeFactor = word.easeFactor {
                        Text("Ease: \(String(format: "%.1f", easeFactor))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 10)
        )
    }
    
    // MARK: - Helpers
    
    private func masteryColor(_ percentage: Int) -> Color {
        switch percentage {
        case 0..<30: return .red
        case 30..<60: return .orange
        case 60..<80: return .yellow
        case 80...100: return .green
        default: return .gray
        }
    }
    
    private func masteryLevelColor(_ level: MasteryLevel?) -> Color {
        switch level {
        case .new: return .gray
        case .learning: return .red
        case .familiar: return .orange
        case .mastered: return .blue
        case .known: return .green
        case .none: return .gray
        default: return .gray
        }
    }
    
    private func timeUntil(_ date: Date) -> String {
        let now = Date()
        if date <= now {
            return "Due"
        }
        
        let components = Calendar.current.dateComponents([.day, .hour], from: now, to: date)
        
        if let days = components.day, days > 0 {
            return days == 1 ? "1 day" : "\(days) days"
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour" : "\(hours) hours"
        } else {
            return "Soon"
        }
    }
}

// MARK: - Supporting Views

struct StatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.hikayaTeal)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
    }
}

struct SRSStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    WordDetailView(
        word: Word(
            arabicText: "مَدِينَة",
            transliteration: "madīna",
            englishMeaning: "city",
            partOfSpeech: .noun,
            rootLetters: "م د ن",
            exampleSentences: [
                ExampleSentence(
                    arabic: "القاهرة مدينة كبيرة.",
                    transliteration: "Al-qāhira madīna kabīra.",
                    english: "Cairo is a big city."
                )
            ],
            difficulty: 2
        ),
        stat: WordStat(
            wordId: UUID(),
            timesReviewed: 15,
            timesCorrect: 12,
            masteryPercentage: 80,
            lastReviewed: Date(),
            isMastered: true
        )
    )
}
