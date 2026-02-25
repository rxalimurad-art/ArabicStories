//
//  WordPopoverView.swift
//  Arabicly
//  Popover view showing word details on tap
//

import SwiftUI

struct WordPopoverView: View {
    let word: QuranWord
    let position: CGPoint
    let isLearned: Bool
    let fontName: String
    let onClose: () -> Void
    let onBookmark: () -> Void
    let onPlayAudio: () -> Void
    
    @State private var showExampleSentences = false
    @State private var dragOffset: CGSize = .zero
    
    init(word: QuranWord, position: CGPoint, isLearned: Bool, fontName: String, onClose: @escaping () -> Void, onBookmark: @escaping () -> Void, onPlayAudio: @escaping () -> Void) {
        self.word = word
        self.position = position
        self.isLearned = isLearned
        self.fontName = fontName
        self.onClose = onClose
        self.onBookmark = onBookmark
        self.onPlayAudio = onPlayAudio
        
        print("🎯 WordPopoverView showing word:")
        print("   Arabic: '\(word.arabicText)'")
        print("   English: '\(word.englishMeaning)'")
        print("   Buckwalter: '\(word.buckwalter ?? "N/A")'")
        print("   Part of Speech: '\(word.morphology.partOfSpeech ?? "N/A")'")
        print("   Root: '\(word.root?.arabic ?? "N/A")'")
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Backdrop
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            onClose()
                        }
                    }
                
                // Popover Card
                VStack(alignment: .center, spacing: 0) {
                    // Handle bar for drag indicator
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 36, height: 4)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            // Arabic Word (Large)
                            Text(word.displayArabic)
                                .font(.custom(fontName, size: 48))
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                            
                            // Learned Badge
                            if isLearned {
                                Label("Already Learned", systemImage: "checkmark.circle.fill")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            
                            // Transliteration (Buckwalter)
                            Text(word.buckwalter ?? "")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            
                            // Part of Speech Badge
                            HStack(spacing: 8) {
                                if word.morphology.partOfSpeech != nil {
                                    Label(word.posDisplayName, systemImage: word.posIcon)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.hikayaTeal.opacity(0.15))
                                        .foregroundStyle(Color.hikayaTeal)
                                        .clipShape(Capsule())
                                }
                                
                                if let root = word.root?.arabic {
                                    Label("Root: \(root)", systemImage: "link")
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.hikayaOrange.opacity(0.15))
                                        .foregroundStyle(Color.hikayaOrange)
                                        .clipShape(Capsule())
                                }
                            }
                            
                            Divider()
                            
                            // English Meaning
                            VStack(spacing: 8) {
                                Text("Meaning")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                
                                Text(word.englishMeaning)
                                    .font(.title3.weight(.medium))
                                    .multilineTextAlignment(.center)
                            }
                            
                            // Action Buttons
                            HStack(spacing: 16) {
                                // Audio Button
                                ActionButton(
                                    icon: "speaker.wave.2.fill",
                                    title: "Listen",
                                    color: .hikayaTeal
                                ) {
                                    onPlayAudio()
                                }
                                
                                // Bookmark Button
                                ActionButton(
                                    icon: word.isBookmarked ?? false ? "bookmark.fill" : "bookmark",
                                    title: word.isBookmarked ?? false ? "Saved" : "Save",
                                    color: word.isBookmarked ?? false ? .hikayaOrange : .gray
                                ) {
                                    onBookmark()
                                }
                            }
                            .padding(.vertical, 8)
                            
                            // Example Sentences (from QuranWord example fields)
                            if word.exampleArabic != nil || word.exampleEnglish != nil {
                                VStack(alignment: .leading, spacing: 12) {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showExampleSentences.toggle()
                                        }
                                    } label: {
                                        HStack {
                                            Text("Example")
                                                .font(.subheadline.weight(.semibold))
                                            
                                            Spacer()
                                            
                                            Image(systemName: showExampleSentences ? "chevron.up" : "chevron.down")
                                                .font(.caption.weight(.semibold))
                                        }
                                        .foregroundStyle(.primary)
                                    }
                                    
                                    if showExampleSentences {
                                        VStack(spacing: 12) {
                                            if let exampleArabic = word.exampleArabic {
                                                Text(exampleArabic)
                                                    .font(.system(size: 18, weight: .medium, design: .serif))
                                                    .multilineTextAlignment(.trailing)
                                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                            }
                                            if let exampleEnglish = word.exampleEnglish {
                                                Text(exampleEnglish)
                                                    .font(.body)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .transition(.move(edge: .top).combined(with: .opacity))
                                    }
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding()
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                .frame(maxWidth: min(geometry.size.width - 40, 400))
                .frame(maxHeight: geometry.size.height * 0.75)
                .position(
                    x: geometry.size.width / 2,
                    y: geometry.size.height - (geometry.size.height * 0.375) - 40
                )
                .offset(dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.height > 0 {
                                dragOffset = CGSize(width: 0, height: value.translation.height)
                            }
                        }
                        .onEnded { value in
                            if value.translation.height > 100 {
                                withAnimation(.spring(response: 0.3)) {
                                    onClose()
                                }
                            } else {
                                withAnimation(.spring(response: 0.3)) {
                                    dragOffset = .zero
                                }
                            }
                        }
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            }
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    var isLoading: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: icon)
                        .font(.title3)
                }
                Text(title)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(color)
            .frame(width: 70)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

// MARK: - Example Sentence Card

struct ExampleSentenceCard: View {
    let sentence: ExampleSentence
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sentence.arabic)
                .font(.body)
                .multilineTextAlignment(.leading)
            
            Text(sentence.transliteration)
                .font(.caption)
                .italic()
                .foregroundStyle(.secondary)
            
            Text(sentence.english)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        
        WordPopoverView(
            word: QuranWord(
                id: "preview-word",
                rank: 1,
                arabicText: "مَدِينَة",
                arabicWithoutDiacritics: "مدينة",
                buckwalter: "madiynap",
                englishMeaning: "city",
                root: QuranRoot(arabic: "م د ن", transliteration: "m-d-n", meaning: "to dwell"),
                morphology: QuranMorphology(partOfSpeech: "N", passive: false),
                occurrenceCount: 17,
                exampleArabic: "القَاهِرَةُ مَدِينَةٌ كَبِيرَةٌ.",
                exampleEnglish: "Cairo is a big city.",
                isBookmarked: true
            ),
            position: .zero,
            isLearned: true,
            fontName: "NotoNaskhArabic",
            onClose: {},
            onBookmark: {},
            onPlayAudio: {}
        )
    }
}
