//
//  QuranWordDetailView.swift
//  Arabicly
//  Detail view for a single Quran word
//

import SwiftUI

struct QuranWordDetailView: View {
    let word: QuranWord
    @State private var relatedWords: [QuranWord] = []
    @State private var isLoadingRelated = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    headerCard
                    
                    // Example Section (if available)
                    if word.exampleArabic != nil || word.exampleEnglish != nil {
                        exampleSection
                    }
                    
                    // Tags Section (if available)
                    if let tags = word.tags, !tags.isEmpty {
                        tagsSection
                    }
                    
                    // Root Section (moved up for prominence)
                    rootSection
                    
                    // Related Words by Root
                    relatedWordsSection
                    
                    // Morphology Section
                    morphologySection
                    
                    // Statistics Section
                    statsSection
                    
                    // Notes Section (if available)
                    if let notes = word.notes, !notes.isEmpty {
                        notesSection
                    }
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
        VStack(spacing: 16) {
            // Arabic Text
            Text(word.arabicText)
                .font(.system(size: 48, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)
            
            // English Meaning
            Text(word.englishMeaning)
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            // Buckwalter
            if let buckwalter = word.buckwalter {
                Text(buckwalter)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            // Badges
            HStack(spacing: 12) {
                if let pos = word.morphology.partOfSpeech {
                    Badge(text: pos, color: .blue)
                }
                if let form = word.formDisplay {
                    Badge(text: form, color: .green)
                }
                Badge(text: "#\(word.rank)", color: .orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }
    
    // MARK: - Example Section
    private var exampleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Example Usage", icon: "text.quote")
            
            VStack(alignment: .leading, spacing: 12) {
                if let exampleArabic = word.exampleArabic {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(exampleArabic)
                            .font(.system(size: 20, weight: .medium, design: .serif))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                
                if let exampleEnglish = word.exampleEnglish {
                    Text(exampleEnglish)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(8)
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
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Morphology Section
    private var morphologySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Morphology", icon: "textformat")
            
            VStack(spacing: 8) {
                MorphologyRow(label: "Part of Speech", value: word.morphology.partOfSpeech ?? "N/A")
                if let desc = word.morphology.posDescription {
                    MorphologyRow(label: "Arabic POS", value: desc, isRTL: true)
                }
                if let lemma = word.morphology.lemma {
                    MorphologyRow(label: "Lemma", value: lemma, isRTL: true)
                }
                if let tense = word.morphology.tense {
                    MorphologyRow(label: "Tense", value: tense)
                }
                if let gender = word.morphology.gender {
                    MorphologyRow(label: "Gender", value: gender)
                }
                if let number = word.morphology.number {
                    MorphologyRow(label: "Number", value: number)
                }
                if let grammaticalCase = word.morphology.grammaticalCase {
                    MorphologyRow(label: "Case", value: grammaticalCase)
                }
                if let state = word.morphology.state {
                    MorphologyRow(label: "State", value: state)
                }
                MorphologyRow(label: "Passive", value: word.morphology.passive ? "Yes" : "No")
                if let breakdown = word.morphology.breakdown {
                    MorphologyRow(label: "Breakdown", value: breakdown)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Root Section
    private var rootSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Root Information", icon: "arrow.branch")
            
            if let root = word.root, let arabic = root.arabic {
                VStack(alignment: .leading, spacing: 12) {
                    // Root Arabic and Transliteration
                    HStack(spacing: 16) {
                        Text(arabic)
                            .font(.system(size: 36, weight: .bold, design: .serif))
                            .foregroundColor(.primary)
                        
                        if let trans = root.transliteration {
                            Text(trans)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    // Root Stats (if available from quran_roots)
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("This word is derived from the Arabic root '\(arabic)'", systemImage: "info.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "minus.circle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No root information available")
                        .foregroundColor(.secondary)
                        .italic()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Related Words Section
    private var relatedWordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Words from Same Root", icon: "text.alignleft")
                Spacer()
                if isLoadingRelated {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let root = word.root?.arabic, !root.isEmpty {
                if relatedWords.isEmpty && !isLoadingRelated {
                    Button("Load related words") {
                        Task { await loadRelatedWords() }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .center)
                } else if !relatedWords.isEmpty {
                    // Show first 5 related words
                    ForEach(relatedWords.prefix(5)) { relatedWord in
                        RelatedWordRow(word: relatedWord)
                    }
                    
                    if relatedWords.count > 5 {
                        Text("+ \(relatedWords.count - 5) more words")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)
                    }
                }
            } else {
                Text("No related words available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .task {
            await loadRelatedWords()
        }
    }
    
    private func loadRelatedWords() async {
        guard let root = word.root?.arabic, !root.isEmpty else { return }
        
        isLoadingRelated = true
        defer { isLoadingRelated = false }
        
        do {
            let words = try await FirebaseService.shared.fetchWordsByRoot(root: root, limit: 50)
            await MainActor.run {
                // Exclude current word from related words
                relatedWords = words.filter { $0.id != word.id }
            }
        } catch {
            print("❌ Error loading related words: \(error)")
        }
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Statistics", icon: "chart.bar")
            
            HStack(spacing: 20) {
                StatItem(value: "\(word.rank)", label: "Rank", color: .blue)
                StatItem(value: word.occurrenceCount.formatted(), label: "Occurrences", color: .green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Related Word Row
struct RelatedWordRow: View {
    let word: QuranWord
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("#\(word.rank)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)
            
            // Arabic
            Text(word.arabicText)
                .font(.system(size: 18, weight: .medium, design: .serif))
                .frame(width: 60, alignment: .trailing)
            
            // English
            Text(word.englishMeaning)
                .font(.subheadline)
                .lineLimit(1)
            
            Spacer()
            
            // Occurrences
            if word.occurrenceCount > 0 {
                Text("\(word.occurrenceCount)×")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            // POS
            if let pos = word.morphology.partOfSpeech {
                Text(pos)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 6)
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
        .padding(.vertical, 4)
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

struct Badge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

// MARK: - Preview
#Preview {
    QuranWordDetailView(word: QuranWord(
        id: "word_00001",
        rank: 1,
        arabicText: "فِى",
        arabicWithoutDiacritics: "فى",
        buckwalter: "fiY",
        englishMeaning: "In",
        root: QuranRoot(arabic: nil, transliteration: "N/A", meaning: nil),
        morphology: QuranMorphology(
            partOfSpeech: "P",
            posDescription: "حرف جر",
            lemma: "فِي",
            form: nil,
            tense: nil,
            gender: nil,
            number: "Plural",
            grammaticalCase: nil,
            passive: false,
            breakdown: "فِى[P]",
            state: nil
        ),
        occurrenceCount: 1098,
        exampleArabic: "قَرَأْتُ الكِتَابَ أَمْسِ",
        exampleEnglish: "I read the book yesterday",
        audioURL: nil,
        tags: ["common", "preposition"],
        notes: "Form I verbal noun pattern",
        createdAt: "2026-02-17T21:38:54.250Z",
        updatedAt: "2026-02-17T21:40:18.701Z"
    ))
}
