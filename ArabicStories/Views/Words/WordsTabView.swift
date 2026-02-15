//
//  WordsTabView.swift
//  Arabicly
//  Combined Words tab: My Words (from stories) + All Words (reference)
//

import SwiftUI

enum WordsTabSection: String, CaseIterable {
    case myWords = "My Words"
    case allWords = "All Words"
    
    var icon: String {
        switch self {
        case .myWords: return "star.fill"
        case .allWords: return "text.book.closed"
        }
    }
}

struct WordsTabView: View {
    @Binding var selectedTab: Int
    @State private var selectedSection: WordsTabSection = .myWords
    
    init(selectedTab: Binding<Int> = .constant(1)) {
        self._selectedTab = selectedTab
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Picker
                Picker("Section", selection: $selectedSection) {
                    ForEach(WordsTabSection.allCases, id: \.self) { section in
                        Label(section.rawValue, systemImage: section.icon)
                            .tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content based on selection
                switch selectedSection {
                case .myWords:
                    MyWordsView(selectedTab: $selectedTab)
                case .allWords:
                    QuranWordsView()
                }
            }
            .navigationTitle("Words")
        }
    }
}

// MARK: - My Words View (Words from Stories + Quiz)
struct MyWordsView: View {
    @Binding var selectedTab: Int
    @State private var viewModel = MyWordsViewModel()
    @State private var showingQuiz = false
    @State private var selectedWord: Word?
    
    init(selectedTab: Binding<Int> = .constant(1)) {
        self._selectedTab = selectedTab
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.unlockedWords.isEmpty {
                    ContentUnavailableView {
                        Label("No Words Yet", systemImage: "lock.fill")
                    } description: {
                        Text("Read stories to unlock words for practice")
                    } actions: {
                        Button("Go to Stories") {
                            selectedTab = 0 // Switch to Learn tab
                        }
                    }
                } else {
                    myWordsList
                }
            }
        }
        .task {
            await viewModel.loadUnlockedWords()
        }
        .sheet(isPresented: $showingQuiz) {
            QuizSessionSheet(viewModel: viewModel)
        }
        .sheet(item: $selectedWord) { word in
            MyWordDetailView(
                word: word,
                isMastered: viewModel.isWordMastered(word.id),
                progress: viewModel.wordProgress(word.id)
            )
        }
    }
    
    private var myWordsList: some View {
        List {
            // Stats Header
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Collection")
                        .font(.headline)
                    
                    Text("Words you've encountered in stories. Take a quiz to master them!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Stats Row
                    HStack(spacing: 20) {
                        StatBadge(
                            value: viewModel.unlockedWords.count,
                            label: "Unlocked",
                            color: .blue
                        )
                        
                        StatBadge(
                            value: viewModel.masteredWords.count,
                            label: "Mastered",
                            color: .green
                        )
                        
                        StatBadge(
                            value: viewModel.wordsToReview.count,
                            label: "To Review",
                            color: .orange
                        )
                    }
                    .padding(.top, 8)
                }
                .padding(.vertical, 8)
            }
            
            // Start Quiz Button
            if !viewModel.quizWords.isEmpty {
                Section {
                    Button {
                        Task {
                            await viewModel.startQuiz()
                            showingQuiz = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                            
                            VStack(alignment: .leading) {
                                Text("Practice \(viewModel.quizWords.count) Words")
                                    .font(.headline)
                                Text("Test your knowledge")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // Unlocked Words List
            Section(header: Text("Words")) {
                ForEach(viewModel.unlockedWords) { word in
                    Button {
                        selectedWord = word
                    } label: {
                        MyWordRow(
                            word: word,
                            isMastered: viewModel.isWordMastered(word.id),
                            progress: viewModel.wordProgress(word.id)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.loadUnlockedWords()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await viewModel.loadUnlockedWords()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
    }
}

// MARK: - Quiz Session Sheet
struct QuizSessionSheet: View {
    @Bindable var viewModel: MyWordsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showExitConfirmation = false
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isSessionComplete {
                    QuizCompleteView(viewModel: viewModel) {
                        dismiss()
                    }
                } else if let question = viewModel.currentQuestion {
                    QuizQuestionView(viewModel: viewModel)
                }
            }
            .navigationTitle("Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("End") {
                        showExitConfirmation = true
                    }
                }
            }
            .alert("End Quiz?", isPresented: $showExitConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("End", role: .destructive) {
                    viewModel.endQuiz()
                    dismiss()
                }
            } message: {
                Text("Your progress will be saved.")
            }
        }
    }
}

// MARK: - Quiz Question View
struct QuizQuestionView: View {
    @Bindable var viewModel: MyWordsViewModel
    @State private var showFeedback = false
    @State private var feedbackIsCorrect = false
    @State private var masteredWordIds: Set<UUID> = []
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.hikayaCream, Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Main Quiz Content
            VStack(spacing: 20) {
                // Header with Progress
                quizHeader
                
                // Word Mastery Progress Card
                wordMasteryCard
                
                // Question Card
                questionCard
                
                // Options Grid
                optionsGrid
                
                Spacer(minLength: 20)
            }
            .padding(.top)
            
            // Feedback Overlay
            if showFeedback {
                feedbackOverlay
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Header
    private var quizHeader: some View {
        VStack(spacing: 16) {
            // Progress Bar with Question Counter
            HStack(spacing: 12) {
                Text("\(viewModel.currentQuestionIndex + 1)/\(viewModel.totalQuestions)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 50)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [Color.hikayaTeal, Color.hikayaOrange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * viewModel.progress, height: 12)
                    }
                }
                .frame(height: 12)
                
                // Score Badge
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    Text("\(viewModel.totalScore)")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(Color.hikayaOrange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.hikayaOrange.opacity(0.15))
                )
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Word Mastery Progress Card
    private var wordMasteryCard: some View {
        Group {
            if let word = viewModel.currentQuestion?.word {
                let progress = viewModel.wordProgress(word.id)
                let isMastered = viewModel.isWordMastered(word.id)
                
                HStack(spacing: 12) {
                    // Progress Ring
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                            .frame(width: 44, height: 44)
                        
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                isMastered ? Color.green : Color.hikayaTeal,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-90))
                        
                        if isMastered {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        } else {
                            Text("\(Int(progress * 100))")
                                .font(.caption.bold())
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Word Mastery")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(isMastered ? "Mastered! 🎉" : "\(Int(progress * 100))/100 points")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isMastered ? .green : .primary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Question Card
    private var questionCard: some View {
        Group {
            if let question = viewModel.currentQuestion {
                VStack(spacing: 24) {
                    // Question Label
                    Text(question.questionType == .arabicToEnglish ? 
                         "What does this mean?" : "What's the Arabic word?")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.hikayaTeal)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.hikayaTeal.opacity(0.12))
                        )
                    
                    // The Word
                    Text(question.questionType == .arabicToEnglish ? 
                         question.word.arabicText : question.word.englishMeaning)
                        .font(.system(size: 52, weight: .bold, design: .serif))
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(.primary)
                        .padding(.horizontal)
                }
                .padding(.vertical, 36)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 6)
                )
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Options Grid
    private var optionsGrid: some View {
        Group {
            if let question = viewModel.currentQuestion {
                VStack(spacing: 12) {
                    ForEach(question.options, id: \.self) { option in
                        ThemedQuizButton(
                            text: option,
                            isSelected: viewModel.selectedOption == option,
                            showResult: viewModel.showResult,
                            isCorrectAnswer: option == question.correctAnswer,
                            isUserSelection: viewModel.selectedOption == option,
                            action: {
                                if !viewModel.showResult {
                                    handleSelection(option, isCorrect: option == question.correctAnswer)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Handle Selection with Feedback
    private func handleSelection(_ option: String, isCorrect: Bool) {
        feedbackIsCorrect = isCorrect
        withAnimation(.spring(response: 0.3)) {
            showFeedback = true
        }
        
        viewModel.selectAnswer(option)
        
        // Hide feedback after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                showFeedback = false
            }
        }
    }
    
    // MARK: - Feedback Overlay
    private var feedbackOverlay: some View {
        VStack {
            HStack(spacing: 16) {
                Image(systemName: feedbackIsCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(feedbackIsCorrect ? .green : .red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(feedbackIsCorrect ? "Correct!" : "Try Again")
                        .font(.title3.bold())
                        .foregroundStyle(feedbackIsCorrect ? .green : .red)
                    
                    if feedbackIsCorrect {
                        Text("+\(viewModel.lastScore) points")
                            .font(.subheadline)
                            .foregroundStyle(Color.hikayaOrange)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: (feedbackIsCorrect ? Color.green : Color.red).opacity(0.25), radius: 20, x: 0, y: 8)
            )
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding(.top, 100)
    }
}

// MARK: - Quiz Complete View
struct QuizCompleteView: View {
    var viewModel: MyWordsViewModel
    var onDone: () -> Void
    
    private var newlyMasteredCount: Int {
        viewModel.masteredWords.filter { word in
            // Words that weren't mastered before but are now
            viewModel.wordMastery[word.id]?.totalScore ?? 0 >= 100
        }.count
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Trophy Icon with Animation
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.15))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                // Title
                VStack(spacing: 8) {
                    Text("Quiz Complete! 🎉")
                        .font(.largeTitle.bold())
                    
                    Text("You've practiced \(viewModel.totalQuestions) words")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Score Card
                VStack(spacing: 16) {
                    Text("\(viewModel.totalScore)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.hikayaOrange)
                    
                    Text("Total Points")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 40)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.hikayaOrange.opacity(0.1))
                )
                
                // Stats Grid
                HStack(spacing: 16) {
                    StatCard(
                        icon: "checkmark.circle.fill",
                        value: "\(viewModel.correctCount)",
                        label: "Correct",
                        color: .green
                    )
                    
                    StatCard(
                        icon: "xmark.circle.fill",
                        value: "\(viewModel.wrongCount)",
                        label: "Wrong",
                        color: .red
                    )
                    
                    StatCard(
                        icon: "percent",
                        value: "\(viewModel.accuracy)%",
                        label: "Accuracy",
                        color: .blue
                    )
                }
                .padding(.horizontal)
                
                // Words Mastered Section
                if !viewModel.masteredWords.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "star.circle.fill")
                                .foregroundStyle(.green)
                            Text("Words Mastered: \(viewModel.masteredWords.count)")
                                .font(.headline)
                        }
                        
                        Text("Great job! You've mastered these words through practice.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // List of mastered words
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.masteredWords.prefix(5)) { word in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                    Text(word.arabicText)
                                        .font(.subheadline)
                                    Text("= \(word.englishMeaning)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            if viewModel.masteredWords.count > 5 {
                                Text("+ \(viewModel.masteredWords.count - 5) more")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.08))
                        )
                    }
                    .padding(.horizontal)
                }
                
                // Done Button
                Button(action: onDone) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Done")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.hikayaTeal, Color.hikayaTeal.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .padding(.vertical, 24)
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - My Word Row
struct MyWordRow: View {
    let word: Word
    let isMastered: Bool
    let progress: Double
    
    var body: some View {
        HStack(spacing: 16) {
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                    .frame(width: 44, height: 44)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        progressColor,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                
                if isMastered {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                } else {
                    Text("\(Int(progress * 100))")
                        .font(.caption.bold())
                }
            }
            
            // Word Info
            VStack(alignment: .leading, spacing: 4) {
                Text(word.arabicText)
                    .font(.title3.bold())
                
                Text(word.englishMeaning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isMastered {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var progressColor: Color {
        switch progress {
        case 0..<0.3: return .red
        case 0.3..<0.7: return .orange
        case 0.7..<1.0: return .yellow
        default: return .green
        }
    }
}

// MARK: - Supporting Views
struct ResultStat: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack {
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Themed Quiz Button
struct ThemedQuizButton: View {
    let text: String
    let isSelected: Bool
    let showResult: Bool
    let isCorrectAnswer: Bool
    let isUserSelection: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(strokeColor, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(selectionFillColor)
                            .frame(width: 16, height: 16)
                    }
                    
                    // Show checkmark or x after result
                    if showResult && isUserSelection {
                        Image(systemName: isCorrectAnswer ? "checkmark" : "xmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                }
                
                Text(text)
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.8)
                    .lineLimit(2)
                
                Spacer()
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(backgroundColor)
                    .shadow(
                        color: shadowColor.opacity(isPressed ? 0.1 : 0.15),
                        radius: isPressed ? 3 : 6,
                        x: 0,
                        y: isPressed ? 1 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(strokeColor, lineWidth: isSelected || (showResult && isUserSelection) ? 2 : 1)
            )
            .foregroundStyle(foregroundColor)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.15), value: isPressed)
            .animation(.spring(response: 0.2), value: showResult)
        }
        .buttonStyle(.plain)
        .disabled(showResult)
        .pressEvents {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
        } onRelease: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = false
            }
        }
    }
    
    private var selectionFillColor: Color {
        if showResult {
            return isCorrectAnswer ? .green : .red
        }
        return Color.hikayaTeal
    }
    
    private var backgroundColor: Color {
        if !showResult {
            return isSelected ? Color.hikayaTeal.opacity(0.08) : Color(.systemBackground)
        }
        
        // After result is shown
        if isUserSelection && isCorrectAnswer {
            return Color.green.opacity(0.12)
        } else if isUserSelection && !isCorrectAnswer {
            return Color.red.opacity(0.12)
        } else if isCorrectAnswer {
            return Color.green.opacity(0.08)  // Show correct answer after selection
        } else {
            return Color(.systemBackground).opacity(0.5)
        }
    }
    
    private var foregroundColor: Color {
        if !showResult {
            return isSelected ? Color.hikayaTeal : .primary
        }
        
        // After result is shown
        if isUserSelection && isCorrectAnswer {
            return .green
        } else if isUserSelection && !isCorrectAnswer {
            return .red
        } else if isCorrectAnswer {
            return .green  // Show correct answer
        } else {
            return .secondary.opacity(0.5)
        }
    }
    
    private var strokeColor: Color {
        if !showResult {
            return isSelected ? Color.hikayaTeal : Color.gray.opacity(0.3)
        }
        
        // After result is shown
        if isUserSelection && isCorrectAnswer {
            return .green
        } else if isUserSelection && !isCorrectAnswer {
            return .red
        } else if isCorrectAnswer {
            return .green  // Show correct answer border
        } else {
            return Color.gray.opacity(0.2)
        }
    }
        } else {
            return Color.gray.opacity(0.2)  // Don't reveal correct answer
        }
    }
    
    private var strokeWidth: CGFloat {
        if !showResult {
            return isPressed ? 3 : 2
        }
        // Only highlight user's selection, not the correct answer
        return isUserSelection ? 3 : 1
    }
    
    private var shadowColor: Color {
        if !showResult {
            return Color.hikayaTeal
        }
        return .black
    }
}

// MARK: - Button Press Effects
struct PressEventsModifier: ViewModifier {
    var onPress: () -> Void
    var onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        onPress()
                    }
                    .onEnded { _ in
                        onRelease()
                    }
            )
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEventsModifier(onPress: onPress, onRelease: onRelease))
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let value: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - My Word Detail View
struct MyWordDetailView: View {
    let word: Word
    let isMastered: Bool
    let progress: Double
    @Environment(\.dismiss) private var dismiss
    
    // Audio & Bookmark states
    @State private var isPlayingAudio = false
    @State private var isBookmarked = false
    
    // Related words
    @State private var relatedWords: [QuranWord] = []
    @State private var isLoadingRelated = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card with Audio & Bookmark
                    headerCard
                    
                    // Root Section (similar to QuranWordDetailView)
                    rootSection
                    
                    // Related Words by Root
                    relatedWordsSection
                    
                    // Linguistic Info Section (similar to Morphology)
                    linguisticInfoSection
                    
                    // Learning Progress Section (similar to Statistics)
                    progressSection
                    
                    // Example Sentences Section
                    examplesSection
                }
                .padding()
            }
            .navigationTitle("Word Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            isBookmarked = word.isBookmarked ?? false
        }
    }
    
    // MARK: - Header Card
    private var headerCard: some View {
        VStack(spacing: 16) {
            // Arabic Text
            Text(word.displayText)
                .font(.system(size: 48, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)
            
            // English Meaning
            Text(word.englishMeaning)
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            
            // Transliteration
            if let transliteration = word.transliteration {
                Text(transliteration)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .italic()
            }
            
            // Badges Row
            HStack(spacing: 12) {
                if let pos = word.partOfSpeech {
                    MyWordBadge(text: pos.displayName, color: .blue)
                }
                if isMastered {
                    MyWordBadge(text: "Mastered", color: .green)
                } else {
                    MyWordBadge(text: "Learning", color: .orange)
                }
                if word.difficulty > 0 {
                    MyWordBadge(text: "Level \(word.difficulty)", color: .purple)
                }
            }
            
            Divider()
            
            // Action Buttons (Audio & Bookmark)
            HStack(spacing: 24) {
                // Audio Button
                ActionButton(
                    icon: isPlayingAudio ? "speaker.wave.2.fill" : "speaker.wave.2",
                    title: "Listen",
                    color: Color.hikayaTeal,
                    isLoading: isPlayingAudio
                ) {
                    playPronunciation()
                }
                
                // Bookmark Button
                ActionButton(
                    icon: isBookmarked ? "bookmark.fill" : "bookmark",
                    title: isBookmarked ? "Saved" : "Save",
                    color: isBookmarked ? .orange : .gray
                ) {
                    toggleBookmark()
                }
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
        VStack(alignment: .leading, spacing: 16) {
            MyWordSectionHeader(title: "Root Information", icon: "arrow.branch")
            
            if let root = word.rootLetters, !root.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    // Root Arabic
                    HStack(spacing: 16) {
                        Text(root)
                            .font(.system(size: 36, weight: .bold, design: .serif))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    // Root Info
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("This word is derived from the Arabic root '\(root)'", systemImage: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "minus.circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No root information available")
                        .foregroundStyle(.secondary)
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
                MyWordSectionHeader(title: "Words from Same Root", icon: "text.alignleft")
                Spacer()
                if isLoadingRelated {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let root = word.rootLetters, !root.isEmpty {
                if relatedWords.isEmpty && !isLoadingRelated {
                    Button("Load related words") {
                        Task { await loadRelatedWords() }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .center)
                } else if !relatedWords.isEmpty {
                    // Show first 5 related words
                    ForEach(relatedWords.prefix(5)) { relatedWord in
                        RelatedQuranWordRow(word: relatedWord)
                    }
                    
                    if relatedWords.count > 5 {
                        Text("+ \(relatedWords.count - 5) more words")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)
                    }
                }
            } else {
                Text("No related words available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
        guard let root = word.rootLetters, !root.isEmpty else { return }
        
        isLoadingRelated = true
        defer { isLoadingRelated = false }
        
        do {
            let words = try await FirebaseService.shared.fetchWordsByRoot(root: root, limit: 50)
            await MainActor.run {
                relatedWords = words
            }
        } catch {
            print("❌ Error loading related words: \(error)")
        }
    }
    
    // MARK: - Linguistic Info Section
    private var linguisticInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MyWordSectionHeader(title: "Morphology", icon: "textformat")
            
            VStack(spacing: 8) {
                MorphologyRow(label: "Part of Speech", value: word.partOfSpeech?.displayName ?? "N/A")
                
                if let root = word.rootLetters, !root.isEmpty {
                    MorphologyRow(label: "Root Letters", value: root, isRTL: true)
                }
                
                if let tashkeel = word.tashkeel, tashkeel != word.arabicText {
                    MorphologyRow(label: "With Tashkeel", value: tashkeel, isRTL: true)
                }
                
                if let transliteration = word.transliteration, !transliteration.isEmpty {
                    MorphologyRow(label: "Transliteration", value: transliteration)
                }
                
                MorphologyRow(label: "Difficulty", value: word.difficulty > 0 ? "Level \(word.difficulty)" : "Not specified")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MyWordSectionHeader(title: "Learning Statistics", icon: "chart.bar")
            
            HStack(spacing: 20) {
                StatItem(value: "\(Int(progress * 100))%", label: "Mastery", color: progressColor)
                StatItem(value: isMastered ? "Yes" : "No", label: "Mastered", color: isMastered ? .green : .gray)
            }
            
            // Progress description
            HStack {
                Image(systemName: isMastered ? "star.fill" : "star")
                    .foregroundStyle(isMastered ? .yellow : .gray)
                Text(isMastered ? "You've mastered this word!" : "Keep practicing to master this word")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Example Sentences Section
    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            MyWordSectionHeader(title: "Example Sentences", icon: "text.quote")
            
            if let examples = word.exampleSentences, !examples.isEmpty {
                VStack(spacing: 16) {
                    ForEach(examples.prefix(3)) { example in
                        ExampleCard(example: example)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("No examples available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Actions
    private func playPronunciation() {
        guard !isPlayingAudio else { return }
        
        isPlayingAudio = true
        
        Task {
            await PronunciationService.shared.playPronunciation(for: word)
            
            // Reset after a delay (simulate audio duration)
            try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            await MainActor.run {
                isPlayingAudio = false
            }
        }
    }
    
    private func toggleBookmark() {
        isBookmarked.toggle()
    }
    
    private var progressColor: Color {
        switch progress {
        case 0..<0.3: return .red
        case 0.3..<0.7: return .orange
        case 0.7..<1.0: return .yellow
        default: return .green
        }
    }
}

// MARK: - Related Quran Word Row
struct RelatedQuranWordRow: View {
    let word: QuranWord
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("#\(word.rank)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
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
                    .foregroundStyle(.green)
            }
            
            // POS
            if let pos = word.morphology.partOfSpeech {
                Text(pos)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Example Card
struct ExampleCard: View {
    let example: ExampleSentence
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Arabic
            Text(example.arabic)
                .font(.system(size: 20, weight: .medium, design: .serif))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            Divider()
            
            // Transliteration
            Text(example.transliteration)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .italic()
            
            // English
            Text(example.english)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let label: String
    let value: String
    var isRTL: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(isRTL ? .trailing : .trailing)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Section Header
struct MyWordSectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.hikayaTeal)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }
}

// MARK: - Badge
struct MyWordBadge: View {
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
    WordsTabView(selectedTab: .constant(1))
}
