//
//  QuranWordDetailView.swift
//  Arabicly
//  Detail view for a single Quran word
//

import SwiftUI
import AVFoundation

struct QuranWordDetailView: View {
    let word: QuranWord
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header Card
                    headerCard
                    
                    // Root Section
                    rootSection
                    
                    // Morphology Section
                    morphologySection
                    
                    // Example Section (if available)
                    if word.exampleArabic != nil || word.exampleEnglish != nil {
                        exampleSection
                    }
                    
                    // Tags Section (if available)
                    if let tags = word.tags, !tags.isEmpty {
                        tagsSection
                    }
                    
                    // Notes Section (if available)
                    if let notes = word.notes, !notes.isEmpty {
                        notesSection
                    }
                    
                    // Metadata
                    metadataSection
                }
                .padding()
            }
            .navigationTitle("Word #\(word.rank)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Header Card
    private var headerCard: some View {
        VStack(spacing: 12) {
            // Arabic Text
            Text(word.arabicText)
                .font(.system(size: 48, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)
            
            // English Meaning
            Text(word.englishMeaning)
                .font(.title2)
                .fontWeight(.medium)
            
            // Buckwalter Transliteration
            if let buckwalter = word.buckwalter {
                Text(buckwalter)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            // Audio Player (if available)
            if let audioURL = word.audioURL, let url = URL(string: audioURL) {
                AudioPlayerView(audioURL: url)
                    .padding(.top, 8)
            }
            
            // Badges
            HStack(spacing: 8) {
                if let pos = word.morphology.partOfSpeech {
                    Badge(text: pos, color: .blue)
                }
                Badge(text: "#\(word.rank)", color: .orange)
                Badge(text: "\(word.occurrenceCount)×", color: .green)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }
    
    // MARK: - Root Section
    private var rootSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Root (المصدر)", icon: "arrow.branch")
            
            if let root = word.root, let arabic = root.arabic {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Text(arabic)
                            .font(.system(size: 28, weight: .bold, design: .serif))
                        
                        if let trans = root.transliteration {
                            Text(trans)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    if let meaning = root.meaning {
                        Text("Meaning: \(meaning)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("No root information")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Morphology Section
    private var morphologySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Morphology (الصرف)", icon: "textformat")
            
            VStack(spacing: 8) {
                // Part of Speech
                MorphologyRow(label: "Part of Speech", value: word.morphology.posDescription ?? word.morphology.partOfSpeech ?? "N/A")
                
                // Lemma
                if let lemma = word.morphology.lemma {
                    MorphologyRow(label: "Lemma", value: lemma, isRTL: true)
                }
                
                // Form
                if let form = word.morphology.form {
                    MorphologyRow(label: "Form", value: "Form \(form)")
                }
                
                // Gender
                if let gender = word.morphology.gender {
                    MorphologyRow(label: "Gender", value: gender == "M" ? "Masculine" : "Feminine")
                }
                
                // Number
                if let number = word.morphology.number {
                    let numberText: String = {
                        switch number {
                        case "S": return "Singular"
                        case "D": return "Dual"
                        case "P": return "Plural"
                        default: return number
                        }
                    }()
                    MorphologyRow(label: "Number", value: numberText)
                }
                
                // Case
                if let grammaticalCase = word.morphology.grammaticalCase {
                    let caseText: String = {
                        switch grammaticalCase {
                        case "NOM": return "Nominative"
                        case "ACC": return "Accusative"
                        case "GEN": return "Genitive"
                        default: return grammaticalCase
                        }
                    }()
                    MorphologyRow(label: "Case", value: caseText)
                }
                
                // State
                if let state = word.morphology.state {
                    MorphologyRow(label: "State", value: state)
                }
                
                // Passive
                if word.morphology.passive {
                    MorphologyRow(label: "Voice", value: "Passive")
                }
                
                // Breakdown
                if let breakdown = word.morphology.breakdown {
                    MorphologyRow(label: "Breakdown", value: breakdown)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Example Section
    private var exampleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Example", icon: "text.quote")
            
            VStack(alignment: .leading, spacing: 8) {
                if let exampleArabic = word.exampleArabic {
                    Text(exampleArabic)
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                
                if let exampleEnglish = word.exampleEnglish {
                    Text(exampleEnglish)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Tags Section
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Tags", icon: "tag")
            
            FlowLayout(spacing: 8) {
                if let tags = word.tags {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.purple.opacity(0.15))
                            .foregroundColor(.purple)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Notes Section
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Notes", icon: "note.text")
            
            Text(word.notes ?? "")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Metadata Section
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Occurrences in Quran:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(word.occurrenceCount)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            HStack {
                Text("Frequency Rank:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("#\(word.rank)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Supporting Views
struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }
}

struct MorphologyRow: View {
    let label: String
    let value: String
    var isRTL: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(isRTL ? .trailing : .leading)
        }
        .padding(.vertical, 2)
    }
}

struct Badge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// Simple Audio Player View
struct AudioPlayerView: View {
    let audioURL: URL
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    
    var body: some View {
        Button(action: {
            togglePlayback()
        }) {
            HStack(spacing: 8) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                Text(isPlaying ? "Stop" : "Play Pronunciation")
                    .font(.subheadline)
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            player?.pause()
            player = nil
            isPlaying = false
        } else {
            player = AVPlayer(url: audioURL)
            player?.play()
            isPlaying = true
            
            // Reset when finished
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: .main) { _ in
                isPlaying = false
                player = nil
            }
        }
    }
}

// MARK: - Preview
#Preview {
    QuranWordDetailView(word: QuranWord(
        id: "bb5a2111-1b6f-4078-bc1f-5e8646ec9c36",
        rank: 145,
        arabicText: "كِتَاب",
        arabicWithoutDiacritics: "كتاب",
        buckwalter: "kitAb",
        englishMeaning: "book",
        root: QuranRoot(arabic: "ك ت ب", transliteration: "k-t-b", meaning: nil),
        morphology: QuranMorphology(
            partOfSpeech: "N",
            posDescription: "اسم",
            lemma: "كِتَاب",
            form: nil,
            tense: nil,
            gender: "M",
            number: "S",
            grammaticalCase: "NOM",
            passive: false,
            breakdown: "كِتَاب (فِعَال pattern from ك-ت-ب)",
            state: nil
        ),
        occurrenceCount: 230,
        exampleArabic: "قَرَأْتُ الكِتَابَ أَمْسِ",
        exampleEnglish: "I read the book yesterday",
        audioURL: "https://storage.googleapis.com/arabicstories-82611.firebasestorage.app/word-audio/bb5a2111-1b6f-4078-bc1f-5e8646ec9c36.mp3",
        tags: ["education", "reading", "literature", "common"],
        notes: "Form I verbal noun pattern",
        createdAt: "2026-02-17T21:38:54.250Z",
        updatedAt: "2026-02-18T15:00:24.000Z"
    ))
}
