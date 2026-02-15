//
//  StoryReaderView.swift
//  Arabicly
//  Bilingual story reader with tap-to-see-meaning feature
//

import SwiftUI

struct StoryReaderView: View {
    var story: Story
    @Bindable var viewModel: StoryReaderViewModel
    @State private var showingSettings = false
    @State private var wordsLoadedRefresh = false  // Trigger refresh when generic words load
    @Environment(\.dismiss) private var dismiss
    
    init(story: Story) {
        self.story = story
        viewModel = StoryReaderViewModel(story: story, wasReset: false)
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
                    readingTime: story.estimatedReadingTime,
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
                
                // Content area
                VStack(spacing: 0) {
                    // Content based on format
                    if viewModel.isMixedFormat {
                        // Mixed Format (Level 1) - English with Arabic words
                        if let segment = viewModel.currentMixedSegment {
                            MixedContentView(
                                segment: segment,
                                storyWords: story.words,
                                viewModel: viewModel,
                                refreshTrigger: wordsLoadedRefresh,
                                onMarkAsDone: {
                                    Task {
                                        await viewModel.markAsCompleted()
                                        dismiss()
                                    }
                                },
                                onRepeat: {
                                    viewModel.resetProgress()
                                }
                            )
                        } else {
                            ContentUnavailableView("No Content", systemImage: "doc.text")
                        }
                    } else {
                        // Bilingual Format (Level 2+) - Full Arabic with English
                        if let segment = viewModel.currentSegment {
                            BilingualContentView(
                                segment: segment,
                                viewModel: viewModel,
                                refreshTrigger: wordsLoadedRefresh
                            )
                        } else {
                            ContentUnavailableView("No Content", systemImage: "doc.text")
                        }
                    }
                    
                    // Bottom Navigation Bar
                    BottomNavigationBar(
                        canGoNext: viewModel.canGoNext,
                        canGoPrevious: viewModel.canGoPrevious,
                        isNightMode: viewModel.isNightMode,
                        onNext: { 
                            Task { 
                                if viewModel.canGoNext {
                                    await viewModel.goToNextSegment()
                                } else {
                                    // On last slide - mark complete and dismiss
                                    await viewModel.markAsCompleted()
                                    dismiss()
                                }
                            }
                        },
                        onPrevious: { Task { await viewModel.goToPreviousSegment() } }
                    )
                }
            }
            
            // Word Popover
            if viewModel.showWordPopover {
                if let mixedWord = viewModel.selectedMixedWord {
                    // Mixed format word popover
                    MixedWordPopoverView(
                        mixedWord: mixedWord,
                        isLearned: viewModel.isMixedWordLearned(mixedWord.wordId),
                        position: viewModel.popoverPosition,
                        fontName: viewModel.arabicFont.fontName,
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
                        fontName: viewModel.arabicFont.fontName,
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
        .sheet(isPresented: $viewModel.showQuranWordDetail) {
            if let quranWord = viewModel.selectedQuranWord {
                QuranWordDetailView(word: quranWord)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            viewModel.incrementViewCount()
            viewModel.startReadingSession() // Start tracking reading time
            // Set up callback for when generic words load
            viewModel.onGenericWordsLoaded = {
                wordsLoadedRefresh.toggle()
            }
        }
        .onDisappear {
            Task {
                await viewModel.stopReadingSession() // Save reading time when leaving
            }
        }
        .onChange(of: wordsLoadedRefresh) { _, _ in
            // Force refresh when generic words are loaded
        }
        .onChange(of: viewModel.hasLoadedQuranWords) { _, newValue in
            if newValue {
                wordsLoadedRefresh.toggle()
            }
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
    let readingTime: TimeInterval
    let onBackTap: () -> Void
    let onSettingsTap: () -> Void
    
    private var formattedReadingTime: String {
        let minutes = Int(readingTime / 60)
        if minutes < 1 {
            return "< 1 min"
        } else {
            return "\(minutes) min"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: onBackTap) {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
            }
            
            // Progress Bar with Reading Time
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
            
            // Reading Time
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption)
                Text(formattedReadingTime)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(isNightMode ? .gray : .secondary)
            
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
    var refreshTrigger: Bool = false
    var onMarkAsDone: () -> Void
    var onRepeat: () -> Void
    
    // Check if this is the last segment
    private var isLastSegment: Bool {
        !viewModel.canGoNext
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Mixed Content - English text with interactive Arabic words
                MixedTextView(
                    text: segment.text,
                    linkedWordIds: segment.linkedWordIds ?? [],
                    storyWords: storyWords,
                    fontSize: viewModel.fontSize,
                    isNightMode: viewModel.isNightMode,
                    fontName: viewModel.arabicFont.fontName,
                    hasMeaningAvailable: { word in
                        viewModel.hasMeaningAvailable(for: word)
                    },
                    onLinkedWordTap: { wordId, position in
                        viewModel.handleMixedWordTap(
                            wordId: wordId,
                            position: position
                        )
                    },
                    onGenericWordTap: { word, position in
                        viewModel.handleWordTap(wordText: word, position: position)
                    }
                )
                .id(refreshTrigger)
                
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
    let text: String
    let linkedWordIds: [String]
    let storyWords: [Word]?
    let fontSize: CGFloat
    let isNightMode: Bool
    let fontName: String
    let hasMeaningAvailable: (String) -> Bool
    let onLinkedWordTap: (String, CGPoint) -> Void
    let onGenericWordTap: (String, CGPoint) -> Void
    
    // Get linked words for this segment
    private var linkedWords: [Word] {
        guard let words = storyWords else { return [] }
        return linkedWordIds.compactMap { wordId in
            words.first { $0.id.uuidString == wordId }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Main text content with proper wrapping
            MixedContentText(
                text: text,
                fontSize: fontSize,
                isNightMode: isNightMode,
                fontName: fontName,
                hasMeaningAvailable: hasMeaningAvailable,
                onWordTap: onGenericWordTap
            )
            
            // Linked Arabic words section (if any) - from story vocabulary
            if !linkedWords.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tap words to learn:")
                        .font(.caption)
                        .foregroundStyle(isNightMode ? .gray : .secondary)
                    
                    FlowLayout(spacing: 12) {
                        ForEach(linkedWords) { word in
                            LinkedWordButton(
                                word: word,
                                isNightMode: isNightMode,
                                fontName: fontName,
                                onTap: { position in
                                    onLinkedWordTap(word.id.uuidString, position)
                                }
                            )
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isNightMode ? Color.white.opacity(0.05) : Color.white)
        )
    }
}

// MARK: - Mixed Content Text with Bold Support

struct MixedContentText: View {
    let text: String
    let fontSize: CGFloat
    let isNightMode: Bool
    let fontName: String
    let hasMeaningAvailable: (String) -> Bool
    let onWordTap: (String, CGPoint) -> Void
    
    // Parsed text components (normal and bold)
    private var parsedComponents: [TextComponent] {
        parseTextWithBoldTags(text)
    }
    
    // Extract Arabic words that have meanings
    private var arabicWordsWithMeanings: [String] {
        extractArabicWords(from: text).filter { hasMeaningAvailable($0) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Text with inline bold support
            MixedFormattedText(
                components: parsedComponents,
                fontSize: fontSize,
                isNightMode: isNightMode
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Show Arabic word chips below (if any have meanings)
            if !arabicWordsWithMeanings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tap to learn:")
                        .font(.caption)
                        .foregroundStyle(isNightMode ? .gray : .secondary)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(arabicWordsWithMeanings, id: \.self) { word in
                            MixedArabicWordChip(
                                word: word,
                                fontSize: fontSize,
                                isNightMode: isNightMode,
                                fontName: fontName,
                                onTap: { position in
                                    onWordTap(word, position)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
    
    // Parse text into components, separating bold and normal text
    private func parseTextWithBoldTags(_ text: String) -> [TextComponent] {
        var components: [TextComponent] = []
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            // Look for <b> tag
            if let boldStartRange = text.range(of: "<b>", range: currentIndex..<text.endIndex) {
                // Add text before <b> as normal
                let beforeBold = String(text[currentIndex..<boldStartRange.lowerBound])
                if !beforeBold.isEmpty {
                    components.append(TextComponent(text: beforeBold, isBold: false))
                }
                
                // Look for closing </b> tag
                let searchStart = boldStartRange.upperBound
                if let boldEndRange = text.range(of: "</b>", range: searchStart..<text.endIndex) {
                    // Extract bold text
                    let boldText = String(text[searchStart..<boldEndRange.lowerBound])
                    if !boldText.isEmpty {
                        components.append(TextComponent(text: boldText, isBold: true))
                    }
                    currentIndex = boldEndRange.upperBound
                } else {
                    // No closing tag, treat rest as normal
                    let remaining = String(text[searchStart..<text.endIndex])
                    if !remaining.isEmpty {
                        components.append(TextComponent(text: remaining, isBold: false))
                    }
                    break
                }
            } else {
                // No more <b> tags, add remaining text as normal
                let remaining = String(text[currentIndex..<text.endIndex])
                if !remaining.isEmpty {
                    components.append(TextComponent(text: remaining, isBold: false))
                }
                break
            }
        }
        
        return components
    }
    
    private func extractArabicWords(from text: String) -> [String] {
        // Remove HTML-like tags for Arabic word extraction
        let cleanText = text.replacingOccurrences(of: "<b>", with: "")
                            .replacingOccurrences(of: "</b>", with: "")
        
        var words: [String] = []
        var currentIndex = cleanText.startIndex
        
        while currentIndex < cleanText.endIndex {
            let char = cleanText[currentIndex]
            
            if ArabicTextUtils.isArabicCharacter(char) {
                var arabicWord = ""
                var endIndex = currentIndex
                
                while endIndex < cleanText.endIndex && 
                      (ArabicTextUtils.isArabicCharacter(cleanText[endIndex]) || 
                       ArabicTextUtils.isDiacritic(cleanText[endIndex])) {
                    arabicWord.append(cleanText[endIndex])
                    endIndex = cleanText.index(after: endIndex)
                }
                
                if !arabicWord.isEmpty && !words.contains(arabicWord) {
                    words.append(arabicWord)
                }
                currentIndex = endIndex
            } else {
                currentIndex = cleanText.index(after: currentIndex)
            }
        }
        
        return words
    }
}

// MARK: - Text Component

struct TextComponent: Identifiable {
    let id = UUID()
    let text: String
    let isBold: Bool
}

// MARK: - Mixed Formatted Text View

struct MixedFormattedText: View {
    let components: [TextComponent]
    let fontSize: CGFloat
    let isNightMode: Bool
    
    var body: some View {
        // Build text by combining components
        components.reduce(Text("")) { result, component in
            let textPart = Text(component.text)
                .font(.system(size: fontSize, weight: component.isBold ? .bold : .regular))
            
            return result + textPart
        }
        .lineSpacing(6)
        .foregroundColor(isNightMode ? .white : .primary)
    }
}

// MARK: - Mixed Arabic Word Chip

struct MixedArabicWordChip: View {
    let word: String
    let fontSize: CGFloat
    let isNightMode: Bool
    let fontName: String
    let onTap: (CGPoint) -> Void
    
    @State private var tapPosition: CGPoint = .zero
    
    var body: some View {
        Text(word)
            .font(.custom(fontName, size: fontSize).bold())
            .foregroundColor(Color.hikayaTeal)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.hikayaTeal.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.hikayaTeal.opacity(0.4), lineWidth: 1)
            )
            .onTapGesture { location in
                tapPosition = location
                onTap(location)
            }
    }
}

// MARK: - Mixed Arabic Word View (Inline)

struct MixedArabicWordView: View {
    let word: String
    let fontSize: CGFloat
    let isNightMode: Bool
    let hasMeaning: Bool
    let fontName: String
    let onTap: (CGPoint) -> Void
    
    @State private var tapPosition: CGPoint = .zero
    
    var body: some View {
        Text(word)
            .font(.custom(fontName, size: fontSize))
            .fontWeight(hasMeaning ? .semibold : .medium)
            .foregroundStyle(textColor)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(backgroundView)
            .overlay(overlayView)
            .contentShape(Rectangle())
            .onTapGesture { location in
                tapPosition = location
                onTap(location)
            }
    }
    
    private var textColor: Color {
        if isNightMode {
            return hasMeaning ? Color.hikayaTeal.opacity(0.9) : .white
        } else {
            return hasMeaning ? Color.hikayaTeal : .primary
        }
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(hasMeaning ? highlightBackgroundColor : Color.clear)
    }
    
    private var overlayView: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(hasMeaning ? borderColor : Color.clear, lineWidth: hasMeaning ? 1 : 0)
    }
    
    private var highlightBackgroundColor: Color {
        isNightMode ? Color.hikayaTeal.opacity(0.15) : Color.hikayaTeal.opacity(0.08)
    }
    
    private var borderColor: Color {
        isNightMode ? Color.hikayaTeal.opacity(0.5) : Color.hikayaTeal.opacity(0.4)
    }
}

// MARK: - Linked Word Button

struct LinkedWordButton: View {
    let word: Word
    let isNightMode: Bool
    let fontName: String
    let onTap: (CGPoint) -> Void
    
    @State private var tapPosition: CGPoint = .zero
    
    var body: some View {
        VStack(spacing: 4) {
            // Arabic text
            Text(word.arabicText)
                .font(.custom(fontName, size: 18))
                .fontWeight(.semibold)
            
            // Transliteration (if available)
            if let transliteration = word.transliteration {
                Text(transliteration)
                    .font(.caption2)
                    .italic()
                    .foregroundStyle(isNightMode ? .gray : .secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isNightMode ? Color.hikayaTeal.opacity(0.2) : Color.hikayaTeal.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.hikayaTeal.opacity(0.4), lineWidth: 1)
        )
        .foregroundStyle(Color.hikayaTeal)
        .contentShape(Rectangle())
        .onTapGesture { location in
            tapPosition = location
            onTap(location)
        }
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3), value: word.id)
    }
}




// MARK: - Linked Mixed Word View (for story vocabulary links)

struct LinkedMixedWordView: View {
    let arabicText: String
    let transliteration: String?
    let wordId: String?
    let isLearned: Bool
    let isNightMode: Bool
    let fontName: String
    let onTap: (CGPoint) -> Void
    
    @State private var tapPosition: CGPoint = .zero
    
    var body: some View {
        VStack(spacing: 2) {
            // Arabic text
            Text(arabicText)
                .font(.custom(fontName, size: 18))
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
    let fontName: String
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
                    .font(.custom(fontName, size: 36))
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
    var refreshTrigger: Bool = false  // Forces refresh when generic words load
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Arabic Text - Tap words to see meaning
                ArabicTextView(
                    text: segment.arabicText,
                    fontSize: viewModel.fontSize,
                    isNightMode: viewModel.isNightMode,
                    fontName: viewModel.arabicFont.fontName,
                    hasMeaningAvailable: { word in
                        viewModel.hasMeaningAvailable(for: word)
                    },
                    onWordTap: { word, position in
                        viewModel.handleWordTap(wordText: word, position: position)
                    }
                )
                .id(refreshTrigger)  // Force re-render when generic words load
                
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
    let fontName: String
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
                    hasMeaning: hasMeaningAvailable(word),
                    fontName: fontName
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
    let fontName: String
    
    var body: some View {
        Text(word)
            .font(.custom(fontName, size: fontSize))
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

// MARK: - Bottom Navigation Bar

struct BottomNavigationBar: View {
    let canGoNext: Bool
    let canGoPrevious: Bool
    let isNightMode: Bool
    let onNext: () -> Void
    let onPrevious: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Previous Button
            Button(action: onPrevious) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Previous")
                        .font(.subheadline.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canGoPrevious 
                            ? (isNightMode ? Color.white.opacity(0.12) : Color.white)
                            : Color.gray.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(canGoPrevious 
                            ? (isNightMode ? Color.white.opacity(0.25) : Color.gray.opacity(0.2))
                            : Color.clear, lineWidth: 1)
                )
                .foregroundStyle(canGoPrevious 
                    ? (isNightMode ? .white : .primary)
                    : Color.gray.opacity(0.4))
            }
            .disabled(!canGoPrevious)
            .padding(.leading, 16)
            
            // Spacer
            Spacer()
                .frame(width: 12)
            
            // Next/Finish Button
            Button(action: onNext) {
                HStack(spacing: 6) {
                    Text(canGoNext ? "Continue" : "Complete")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: canGoNext ? "arrow.right" : "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.hikayaTeal)
                )
                .foregroundStyle(.white)
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 12)
        .background(isNightMode ? Color.black : Color.hikayaCream)
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
                    
                    // Arabic Font Picker
                    Picker("Arabic Font", selection: $viewModel.arabicFont) {
                        ForEach(ArabicFont.allCases) { font in
                            Text(font.rawValue)
                                .tag(font)
                        }
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
                
                Section("Reading") {
                    Toggle("Highlight Arabic Words", isOn: .constant(true))
                        .disabled(true) // Coming soon
                }
                
                Section("Story Progress") {
                    Button("Reset Progress") {
                        viewModel.resetProgress()
                        dismiss()
                    }
                    .foregroundStyle(.red)
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
