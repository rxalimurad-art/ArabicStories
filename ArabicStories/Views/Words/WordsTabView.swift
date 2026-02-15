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
    
    init(selectedTab: Binding<Int> = .constant(1)) {
        self._selectedTab = selectedTab
    }
    
    var body: some View {
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
        .task {
            await viewModel.loadUnlockedWords()
        }
        .sheet(isPresented: $showingQuiz) {
            QuizSessionSheet(viewModel: viewModel)
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
                    MyWordRow(
                        word: word,
                        isMastered: viewModel.isWordMastered(word.id),
                        progress: viewModel.wordProgress(word.id)
                    )
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
    
    var body: some View {
        ZStack {
            // Main Quiz Content
            VStack(spacing: 16) {
                // Header with Progress
                quizHeader
                
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
        VStack(spacing: 12) {
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.hikayaTeal, Color.hikayaTeal.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * viewModel.progress, height: 8)
                }
            }
            .frame(height: 8)
            .padding(.horizontal)
            
            // Stats Row
            HStack {
                Label("\(viewModel.currentQuestionIndex + 1)/\(viewModel.totalQuestions)", systemImage: "number.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Label("\(viewModel.totalScore)", systemImage: "star.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.hikayaOrange)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Question Card
    private var questionCard: some View {
        Group {
            if let question = viewModel.currentQuestion {
                VStack(spacing: 20) {
                    // Question Label
                    Text(question.questionType == .arabicToEnglish ? 
                         "What does this mean?" : "What's the Arabic word?")
                        .font(.headline)
                        .foregroundStyle(Color.hikayaTeal)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.hikayaTeal.opacity(0.1))
                        .clipShape(Capsule())
                    
                    // The Word
                    Text(question.questionType == .arabicToEnglish ? 
                         question.word.arabicText : question.word.englishMeaning)
                        .font(.system(size: 56, weight: .bold))
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(.primary)
                        .padding(.horizontal)
                }
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 4)
                )
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Options Grid
    private var optionsGrid: some View {
        Group {
            if let question = viewModel.currentQuestion {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
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
                .padding(.top, 8)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.2)) {
                showFeedback = false
            }
        }
    }
    
    // MARK: - Feedback Overlay
    private var feedbackOverlay: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: feedbackIsCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(feedbackIsCorrect ? .green : .red)
                
                Text(feedbackIsCorrect ? "Correct!" : "Wrong")
                    .font(.title3.bold())
                    .foregroundStyle(feedbackIsCorrect ? .green : .red)
                
                if feedbackIsCorrect {
                    Text("+\(viewModel.lastScore)")
                        .font(.title3.bold())
                        .foregroundStyle(Color.hikayaOrange)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: (feedbackIsCorrect ? Color.green : Color.red).opacity(0.3), radius: 12, x: 0, y: 4)
            )
            
            Spacer()
        }
        .padding(.top, 60)
    }
}

// MARK: - Quiz Complete View
struct QuizCompleteView: View {
    var viewModel: MyWordsViewModel
    var onDone: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 80))
                .foregroundStyle(.yellow)
            
            Text("Quiz Complete!")
                .font(.largeTitle.bold())
            
            Text("Score: \(viewModel.totalScore)")
                .font(.title)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 32) {
                ResultStat(value: "\(viewModel.correctCount)", label: "Correct")
                ResultStat(value: "\(viewModel.wrongCount)", label: "Wrong")
                ResultStat(value: "\(viewModel.accuracy)%", label: "Accuracy")
            }
            
            Button("Done", action: onDone)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 40)
        }
        .padding()
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
            HStack {
                Spacer()
                
                Text(text)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                
                Spacer()
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(backgroundColor)
                    .shadow(
                        color: shadowColor.opacity(isPressed ? 0.1 : 0.2),
                        radius: isPressed ? 4 : 8,
                        x: 0,
                        y: isPressed ? 2 : 4
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
            .foregroundStyle(foregroundColor)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2), value: isPressed)
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
    
    private var backgroundColor: Color {
        if !showResult {
            return isPressed ? Color.hikayaTeal.opacity(0.1) : Color(.systemBackground)
        }
        
        // After result is shown - ONLY show user's selection, don't reveal correct answer
        if isUserSelection && isCorrectAnswer {
            return Color.green.opacity(0.15)  // User got it right
        } else if isUserSelection && !isCorrectAnswer {
            return Color.red.opacity(0.15)    // User got it wrong
        } else {
            return Color(.systemBackground).opacity(0.6)  // Other options fade (no hint!)
        }
    }
    
    private var foregroundColor: Color {
        if !showResult {
            return .primary
        }
        
        // After result is shown - ONLY show user's selection
        if isUserSelection && isCorrectAnswer {
            return .green
        } else if isUserSelection && !isCorrectAnswer {
            return .red
        } else {
            return .secondary.opacity(0.6)  // Don't reveal correct answer
        }
    }
    
    private var strokeColor: Color {
        if !showResult {
            return isPressed ? Color.hikayaTeal : Color.hikayaTeal.opacity(0.3)
        }
        
        // After result is shown - ONLY show user's selection
        if isUserSelection && isCorrectAnswer {
            return .green
        } else if isUserSelection && !isCorrectAnswer {
            return .red
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

// MARK: - Preview
#Preview {
    WordsTabView(selectedTab: .constant(1))
}
