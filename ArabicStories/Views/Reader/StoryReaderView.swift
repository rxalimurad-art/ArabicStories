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
                
                // Vocabulary Progress Bar (for mixed format)
                if viewModel.isMixedFormat && viewModel.totalVocabularyCount > 0 {
                    VocabularyProgressBar(
                        learnedCount: viewModel.learnedVocabularyCount,
                        totalCount: viewModel.totalVocabularyCount,
                        isNightMode: viewModel.isNightMode
                    )
                    .padding(.horizontal)
                }
                
                // Content based on format
                if viewModel.isMixedFormat {
                    // Mixed Format (Level 1) - English with Arabic words
                    if let segment = viewModel.currentMixedSegment {
                        MixedContentView(
                            segment: segment,
                            storyWords: story.words,
                            viewModel: viewModel
                        )
                    } else {
                        ContentUnavailableView("No Content", systemImage: "doc.text")
                    }
                } else {
                    // Bilingual Format (Level 2+) - Full Arabic with English
                    if let segment = viewModel.currentSegment {
                        BilingualContentView(
                            segment: segment,
                            viewModel: viewModel
                        )
                    } else {
                        ContentUnavailableView("No Content", systemImage: "doc.text")
                    }
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
            if viewModel.showWordPopover {
                if let mixedWord = viewModel.selectedMixedWord {
                    // Mixed format word popover
                    MixedWordPopoverView(
                        mixedWord: mixedWord,
                        isLearned: viewModel.isMixedWordLearned(mixedWord.wordId),
                        position: viewModel.popoverPosition,
                        onClose: { viewModel.closeWordPopover() },
                        onPlayAudio: {
                            if let word = viewModel.selectedWord {
                                viewModel.playWordPronunciation(word)
                            }
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                } else if let word = viewModel.selectedWord {
                    // Bilingual format word popover
                    WordPopoverView(
                        word: word,
                        position: viewModel.popoverPosition,
                        isLearned: viewModel.isWordLearned(word.id.uuidString),
                        onClose: { viewModel.closeWordPopover() },
                        onBookmark: { viewModel.toggleWordBookmark(word) },
                        onPlayAudio: { viewModel.playWordPronunciation(word) }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
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

// MARK: - Vocabulary Progress Bar

struct VocabularyProgressBar: View {
    let learnedCount: Int
    let totalCount: Int
    let isNightMode: Bool
    
    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(learnedCount) / Double(totalCount)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Words Learned")
                    .font(.caption)
                    .foregroundStyle(isNightMode ? .gray : .secondary)
                
                Spacer()
                
                Text("\(learnedCount)/\(totalCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.hikayaTeal)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isNightMode ? Color.white.opacity(0.1) : Color(.systemGray5))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [Color.hikayaTeal, Color.hikayaTeal.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isNightMode ? Color.white.opacity(0.05) : Color.white)
        )
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

// MARK: - Mixed Content View (Level 1)

struct MixedContentView: View {
    let segment: MixedContentSegment
    let storyWords: [Word]?
    var viewModel: StoryReaderViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Mixed Content - English with embedded Arabic words
                MixedTextView(
                    contentParts: segment.contentParts,
                    storyWords: storyWords,
                    fontSize: viewModel.fontSize,
                    isNightMode: viewModel.isNightMode,
                    onWordTap: { wordId, arabicText, transliteration, position in
                        viewModel.handleMixedWordTap(
                            wordId: wordId,
                            arabicText: arabicText,
                            transliteration: transliteration,
                            position: position
                        )
                    }
                )
                
                // Cultural Note
                if let culturalNote = segment.culturalNote {
                    NoteCard(
                        title: "Cultural Note",
                        content: culturalNote,
                        icon: "globe",
                        isNightMode: viewModel.isNightMode
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Mixed Text View

struct MixedTextView: View {
    let contentParts: [MixedContentPart]
    let storyWords: [Word]?
    let fontSize: CGFloat
    let isNightMode: Bool
    let onWordTap: (String, String, String?, CGPoint) -> Void
    
    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(contentParts) { part in
                switch part.type {
                case .text:
                    Text(part.text)
                        .font(.system(size: fontSize))
                        .foregroundStyle(isNightMode ? .white : .primary)
                case .arabicWord:
                    MixedArabicWordView(
                        arabicText: part.text,
                        transliteration: part.transliteration,
                        wordId: part.wordId,
                        isLearned: storyWords?.first { $0.id.uuidString == part.wordId } != nil,
                        isNightMode: isNightMode,
                        onTap: { position in
                            onWordTap(
                                part.wordId ?? "",
                                part.text,
                                part.transliteration,
                                position
                            )
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Mixed Arabic Word View

struct MixedArabicWordView: View {
    let arabicText: String
    let transliteration: String?
    let wordId: String?
    let isLearned: Bool
    let isNightMode: Bool
    let onTap: (CGPoint) -> Void
    
    @State private var tapPosition: CGPoint = .zero
    
    var body: some View {
        VStack(spacing: 2) {
            // Arabic text
            Text(arabicText)
                .font(.custom("NotoNaskhArabic", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(isNightMode ? Color.hikayaTeal : Color.hikayaTeal)
            
            // Transliteration (optional)
            if let transliteration = transliteration {
                Text(transliteration)
                    .font(.caption2)
                    .italic()
                    .foregroundStyle(isNightMode ? .gray : .secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isLearned ? 
                    (isNightMode ? Color.hikayaTeal.opacity(0.2) : Color.hikayaTeal.opacity(0.1)) :
                    (isNightMode ? Color.white.opacity(0.05) : Color(.systemGray6))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isLearned ? Color.hikayaTeal.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { location in
            tapPosition = location
            onTap(location)
        }
        .scaleEffect(isLearned ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isLearned)
    }
}

// MARK: - Mixed Word Popover View

struct MixedWordPopoverView: View {
    let mixedWord: StoryReaderViewModel.MixedWordInfo
    let isLearned: Bool
    let position: CGPoint
    let onClose: () -> Void
    let onPlayAudio: () -> Void
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
            
            // Popover
            VStack(spacing: 16) {
                // Arabic word
                Text(mixedWord.arabicText)
                    .font(.custom("NotoNaskhArabic", size: 36))
                    .foregroundStyle(.primary)
                
                // Transliteration
                if let transliteration = mixedWord.transliteration {
                    Text(transliteration)
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // English meaning
                if let meaning = mixedWord.englishMeaning {
                    Text(meaning)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(Color.hikayaTeal)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Learn this word!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Learned indicator
                if isLearned {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Learned")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                    }
                    .padding(.top, 4)
                }
                
                // Action buttons
                HStack(spacing: 20) {
                    Button(action: onPlayAudio) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title2)
                            .foregroundStyle(Color.hikayaTeal)
                            .frame(width: 44, height: 44)
                            .background(Color.hikayaTeal.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.gray)
                            .frame(width: 44, height: 44)
                    }
                }
            }
            .padding()
            .frame(maxWidth: 300)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            )
            .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
        }
    }
}

// MARK: - Bilingual Content View (Level 2+)

struct BilingualContentView: View {
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
                    hasMeaningAvailable: { word in
                        viewModel.hasMeaningAvailable(for: word)
                    },
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
    let hasMeaningAvailable: (String) -> Bool
    let onWordTap: (String, CGPoint) -> Void
    
    var body: some View {
        FlowLayout(spacing: 8) {
            let words = text.components(separatedBy: .whitespaces)
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                ArabicWordView(
                    word: word,
                    fontSize: fontSize,
                    isNightMode: isNightMode,
                    hasMeaning: hasMeaningAvailable(word)
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
    let hasMeaning: Bool
    
    var body: some View {
        Text(word)
            .font(.custom("NotoNaskhArabic", size: fontSize))
            .fontWeight(hasMeaning ? .semibold : .medium)
            .foregroundStyle(textColor)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(backgroundView)
            .overlay(overlayView)
            .contentShape(Rectangle())
    }
    
    private var textColor: Color {
        if isNightMode {
            return hasMeaning ? Color.hikayaTeal.opacity(0.9) : .white
        } else {
            return hasMeaning ? Color.hikayaTeal : .primary
        }
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(hasMeaning ? highlightBackgroundColor : Color.clear)
    }
    
    private var overlayView: some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(hasMeaning ? borderColor : Color.clear, lineWidth: hasMeaning ? 1.5 : 0)
    }
    
    private var highlightBackgroundColor: Color {
        isNightMode ? Color.hikayaTeal.opacity(0.15) : Color.hikayaTeal.opacity(0.08)
    }
    
    private var borderColor: Color {
        isNightMode ? Color.hikayaTeal.opacity(0.5) : Color.hikayaTeal.opacity(0.4)
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
            .disabled(false) // Allow tapping next even at end to complete
            .opacity(canGoNext ? 1 : 0.5)
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
                    
                    // Show English (only for bilingual)
                    if !viewModel.isMixedFormat {
                        Toggle("Show Translation", isOn: Binding(
                            get: { viewModel.showEnglish },
                            set: { _ in viewModel.toggleEnglish() }
                        ))
                        
                        Toggle("Show Transliteration", isOn: Binding(
                            get: { viewModel.showTransliteration },
                            set: { _ in viewModel.toggleTransliteration() }
                        ))
                    }
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
                
                // Vocabulary info for mixed format
                if viewModel.isMixedFormat && viewModel.totalVocabularyCount > 0 {
                    Section("Vocabulary") {
                        HStack {
                            Text("Words in Story")
                            Spacer()
                            Text("\(viewModel.totalVocabularyCount)")
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Words Learned")
                            Spacer()
                            Text("\(viewModel.learnedVocabularyCount)")
                                .foregroundStyle(Color.hikayaTeal)
                        }
                    }
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
        format: .bilingual,
        difficultyLevel: 2,
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
