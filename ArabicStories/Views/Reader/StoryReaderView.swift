//
//  StoryReaderView.swift
//  Hikaya
//  Bilingual story reader with tap-to-see-meaning feature
//

import SwiftUI

struct StoryReaderView: View {
    var story: Story
    @Bindable var viewModel: StoryReaderViewModel
    @State private var showingSettings = false
    @Environment(\.dismiss) private var dismiss
    
    init(story: Story) {
        self.story = story
        viewModel = StoryReaderViewModel(story: story)
    }
    
    var body: some View {
        ZStack {
            // Background
            viewModel.isNightMode ? Color.black.ignoresSafeArea() : Color.hikayaCream.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
                ReaderNavigationBar(
                    progress: viewModel.readingProgress,
                    isNightMode: viewModel.isNightMode,
                    onBackTap: { dismiss() },
                    onSettingsTap: { showingSettings = true }
                )
                
                // Content
                if let segment = viewModel.currentSegment {
                    StoryContentView(
                        segment: segment,
                        viewModel: viewModel
                    )
                } else {
                    ContentUnavailableView("No Content", systemImage: "doc.text")
                }
                
                // Bottom Controls
                ReaderBottomBar(
                    viewModel: viewModel,
                    canGoNext: viewModel.canGoNext,
                    canGoPrevious: viewModel.canGoPrevious,
                    onNext: { Task { await viewModel.goToNextSegment() } },
                    onPrevious: { Task { await viewModel.goToPreviousSegment() } }
                )
            }
            
            // Word Popover
            if viewModel.showWordPopover, let word = viewModel.selectedWord {
                WordPopoverView(
                    word: word,
                    position: viewModel.popoverPosition,
                    isLearned: viewModel.isWordLearned(word.id.uuidString),
                    onClose: { viewModel.closeWordPopover() },
                    onBookmark: { viewModel.toggleWordBookmark(word) },
                    onPlayAudio: { viewModel.playWordPronunciation(word) },
                    onAddToFlashcards: { viewModel.addWordToFlashcards(word) }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingSettings) {
            ReaderSettingsView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.incrementViewCount()
        }
    }
}

// MARK: - Reader Navigation Bar

struct ReaderNavigationBar: View {
    let progress: Double
    let isNightMode: Bool
    let onBackTap: () -> Void
    let onSettingsTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: onBackTap) {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isNightMode ? Color.white.opacity(0.2) : Color.black.opacity(0.1))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.hikayaTeal)
                        .frame(width: geometry.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)
            
            Button(action: onSettingsTap) {
                Image(systemName: "textformat.size")
                    .font(.title3)
            }
        }
        .foregroundStyle(isNightMode ? .white : .primary)
        .padding()
        .background(isNightMode ? Color.black : Color.hikayaCream)
    }
}

// MARK: - Story Content View

struct StoryContentView: View {
    let segment: StorySegment
    var viewModel: StoryReaderViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Arabic Text - Tap words to see meaning
                ArabicTextView(
                    text: segment.arabicText,
                    fontSize: viewModel.fontSize,
                    isNightMode: viewModel.isNightMode,
                    onWordTap: { word, position in
                        viewModel.handleWordTap(wordText: word, position: position)
                    }
                )
                
                // Transliteration (optional)
                if viewModel.showTransliteration,
                   let transliteration = segment.transliteration {
                    TransliterationView(
                        text: transliteration,
                        isNightMode: viewModel.isNightMode
                    )
                }
                
                // English Translation (optional)
                if viewModel.showEnglish {
                    EnglishTextView(
                        text: segment.englishText,
                        isNightMode: viewModel.isNightMode
                    )
                }
                
                // Cultural/Grammar Notes
                if let culturalNote = segment.culturalNote {
                    NoteCard(
                        title: "Cultural Note",
                        content: culturalNote,
                        icon: "globe",
                        isNightMode: viewModel.isNightMode
                    )
                }
                
                if let grammarNote = segment.grammarNote {
                    NoteCard(
                        title: "Grammar Note",
                        content: grammarNote,
                        icon: "textformat.abc",
                        isNightMode: viewModel.isNightMode
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Arabic Text View with Tap Detection

struct ArabicTextView: View {
    let text: String
    let fontSize: CGFloat
    let isNightMode: Bool
    let onWordTap: (String, CGPoint) -> Void
    
    var body: some View {
        FlowLayout(spacing: 8) {
            let words = text.components(separatedBy: .whitespaces)
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                ArabicWordView(
                    word: word,
                    fontSize: fontSize,
                    isNightMode: isNightMode
                )
                .onTapGesture { location in
                    onWordTap(word, location)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Arabic Word View

struct ArabicWordView: View {
    let word: String
    let fontSize: CGFloat
    let isNightMode: Bool
    
    var body: some View {
        Text(word)
            .font(.custom("NotoNaskhArabic", size: fontSize))
            .fontWeight(.medium)
            .foregroundStyle(isNightMode ? .white : .primary)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.clear)
            )
            .contentShape(Rectangle())
    }
}

// MARK: - Transliteration View

struct TransliterationView: View {
    let text: String
    let isNightMode: Bool
    
    var body: some View {
        Text(text)
            .font(.subheadline)
            .italic()
            .foregroundStyle(isNightMode ? Color.gray : Color.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isNightMode ? Color.white.opacity(0.05) : Color.hikayaTeal.opacity(0.05))
            )
    }
}

// MARK: - English Text View

struct EnglishTextView: View {
    let text: String
    let isNightMode: Bool
    
    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(isNightMode ? Color.gray : Color.primary.opacity(0.8))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isNightMode ? Color.white.opacity(0.05) : Color.white)
            )
    }
}

// MARK: - Note Card

struct NoteCard: View {
    let title: String
    let content: String
    let icon: String
    let isNightMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Color.hikayaOrange)
            
            Text(content)
                .font(.caption)
                .foregroundStyle(isNightMode ? .gray : .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isNightMode ? Color.hikayaOrange.opacity(0.1) : Color.hikayaOrange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.hikayaOrange.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Reader Bottom Bar

struct ReaderBottomBar: View {
    var viewModel: StoryReaderViewModel
    let canGoNext: Bool
    let canGoPrevious: Bool
    let onNext: () -> Void
    let onPrevious: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            // Previous Button
            Button(action: onPrevious) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
            }
            .disabled(!canGoPrevious)
            .opacity(canGoPrevious ? 1 : 0.3)
            
            // Audio Controls
            AudioControlView(viewModel: viewModel)
            
            // Next Button
            Button(action: onNext) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
            }
            .disabled(!canGoNext)
            .opacity(canGoNext ? 1 : 0.3)
        }
        .foregroundStyle(Color.hikayaTeal)
        .padding()
        .background(viewModel.isNightMode ? Color.black : Color.hikayaCream)
    }
}

// MARK: - Audio Control View

struct AudioControlView: View {
    var viewModel: StoryReaderViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause
            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
            }
            
            // Speed Button
            Menu {
                ForEach(AudioSpeed.allCases, id: \.self) { speed in
                    Button {
                        viewModel.setPlaybackSpeed(speed)
                    } label: {
                        Text(speed.displayName)
                        if viewModel.playbackSpeed == speed {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                Text(viewModel.playbackSpeed.displayName)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.hikayaTeal.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Reader Settings View

struct ReaderSettingsView: View {
    @Bindable var viewModel: StoryReaderViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Display") {
                    // Font Size
                    HStack {
                        Text("A")
                            .font(.caption)
                        
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.fontSize) },
                                set: { viewModel.fontSize = CGFloat($0) }
                            ),
                            in: 14...32,
                            step: 2
                        )
                        
                        Text("A")
                            .font(.title2)
                    }
                    
                    // Night Mode
                    Toggle("Night Mode", isOn: Binding(
                        get: { viewModel.isNightMode },
                        set: { _ in viewModel.toggleNightMode() }
                    ))
                    
                    // Show English
                    Toggle("Show Translation", isOn: Binding(
                        get: { viewModel.showEnglish },
                        set: { _ in viewModel.toggleEnglish() }
                    ))
                    
                    // Show Transliteration
                    Toggle("Show Transliteration", isOn: Binding(
                        get: { viewModel.showTransliteration },
                        set: { _ in viewModel.toggleTransliteration() }
                    ))
                }
                
                Section("Audio") {
                    Toggle("Auto-scroll with audio", isOn: $viewModel.autoScrollEnabled)
                }
                
                Section("Story Progress") {
                    Button("Reset Progress") {
                        viewModel.resetProgress()
                        dismiss()
                    }
                    .foregroundStyle(.red)
                    
                    Button("Mark as Completed") {
                        Task {
                            await viewModel.markAsCompleted()
                            dismiss()
                        }
                    }
                    .foregroundStyle(Color.hikayaTeal)
                }
            }
            .navigationTitle("Reader Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: result.positions[index].x + bounds.minX, 
                                      y: result.positions[index].y + bounds.minY), 
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Preview

#Preview {
    StoryReaderView(story: Story(
        title: "The Wise Merchant",
        titleArabic: "التاجر الحكيم",
        storyDescription: "A story about wisdom",
        author: "Traditional",
        difficultyLevel: 1,
        segments: [
            StorySegment(
                index: 0,
                arabicText: "كان يا ما كان، في قديم الزمان، في مدينة بغداد الجميلة، تاجرٌ اسمه أحمد.",
                englishText: "Once upon a time, in ancient days, in the beautiful city of Baghdad, there was a merchant named Ahmad.",
                transliteration: "Kāna yā mā kān, fī qadīm az-zamān..."
            )
        ]
    ))
}
