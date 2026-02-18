//
//  WordsTabView.swift
//  Arabicly
//  Combined Words tab: My Words (from stories) + All Words (reference)
//

import SwiftUI

struct WordsTabView: View {
    @Binding var selectedTab: Int

    init(selectedTab: Binding<Int> = .constant(1)) {
        self._selectedTab = selectedTab
    }

    var body: some View {
        NavigationStack {
            MyWordsView(selectedTab: $selectedTab)
                .navigationTitle("Words")
        }
    }
}

// MARK: - My Words View (Words from Stories + Quiz)
struct MyWordsView: View {
    @Binding var selectedTab: Int
    @State private var viewModel = MyWordsViewModel()
    @State private var showingQuiz = false
    @State private var selectedWord: QuranWord?
    
    init(selectedTab: Binding<Int> = .constant(1)) {
        self._selectedTab = selectedTab
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                // Skeleton Loading State
                skeletonLoadingView
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
        .sheet(isPresented: $showingQuiz, onDismiss: {
            // Refresh word mastery data when quiz is dismissed
            Task {
                await viewModel.loadUnlockedWords()
            }
        }) {
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
        ScrollView {
            LazyVStack(spacing: 16) {
                // Stats Header Card
                statsHeaderCard

                // Sort & Filter Bar
                sortFilterBar

                // Practice Button Card
                if !viewModel.quizWords.isEmpty {
                    practiceCard
                }

                // Words List
                let words = viewModel.sortedAndFilteredWords
                if words.isEmpty {
                    Text("No words match the current filter")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                } else {
                    ForEach(words) { word in
                        Button {
                            selectedWord = word
                        } label: {
                            MyWordRow(
                                word: word,
                                isMastered: viewModel.isWordMastered(word.id),
                                progress: viewModel.wordProgress(word.id),
                                isStarred: word.isBookmarked == true,
                                onToggleStar: {
                                    viewModel.toggleStarWord(wordId: word.id)
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color.hikayaBackground.ignoresSafeArea())
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

    // MARK: - Stats Header Card
    private var statsHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Collection")
                .font(.headline)

            Text("Words you've encountered in stories. Take a quiz to master them!")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Skeleton Loading View
    
    private var skeletonLoadingView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Stats Header Skeleton
                VStack(spacing: 12) {
                    HStack(spacing: 20) {
                        ForEach(0..<3, id: \.self) { _ in
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 24)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 80, height: 12)
                            }
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
                .shimmer()
                
                // Sort/Filter Bar Skeleton
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 36)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 36)
                }
                .shimmer()
                
                // Word Cards Skeleton
                ForEach(0..<8, id: \.self) { _ in
                    HStack(spacing: 16) {
                        // Progress Ring Skeleton
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 44, height: 44)
                        
                        // Word Info Skeleton
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 120, height: 20)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 180, height: 14)
                        }
                        
                        Spacer()
                        
                        // Badge Skeleton
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 50, height: 24)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )
                    .shimmer()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color.hikayaBackground.ignoresSafeArea())
    }

    // MARK: - Sort & Filter Bar
    private var sortFilterBar: some View {
        VStack(spacing: 10) {
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(WordFilterOption.allCases, id: \.self) { option in
                        FilterChip(
                            title: option.rawValue,
                            isSelected: viewModel.filterOption == option,
                            color: Color.hikayaTeal
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.filterOption = option
                            }
                        }
                    }

                    Spacer()

                    // Sort menu
                    Menu {
                        ForEach(WordSortOption.allCases, id: \.self) { option in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.sortOption = option
                                }
                            } label: {
                                Label(option.rawValue, systemImage: option.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                            Text(viewModel.sortOption.rawValue)
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(Color.hikayaTeal)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Practice Card
    private var practiceCard: some View {
        Button {
            Task {
                await viewModel.startQuiz()
                showingQuiz = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.hikayaTeal)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Practice \(viewModel.quizWords.count) Words")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Test your knowledge")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.hikayaTeal.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
                    Task {
                        await viewModel.endQuiz()
                        dismiss()
                    }
                }
            } message: {
                Text("Your progress will be saved.")
            }
            .alert("Quiz Saved", isPresented: $viewModel.showErrorAlert) {
                Button("OK") { }
            } message: {
                if let message = viewModel.errorMessage {
                    Text(message)
                }
            }
        }
    }
}

// MARK: - Quiz Question View
struct QuizQuestionView: View {
    @Bindable var viewModel: MyWordsViewModel
    @State private var showFeedback = false
    @State private var feedbackIsCorrect = false
    @State private var feedbackScore = 0

    var body: some View {
        ZStack {
            // Background
            Color.hikayaBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Header with Progress
                    quizHeader

                    // Streak badge
                    if viewModel.currentStreak >= 2 {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("\(viewModel.currentStreak) streak!")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.orange)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.12))
                        )
                        .transition(.scale.combined(with: .opacity))
                    }

                    // Word Mastery Progress Card
                    wordMasteryCard

                    // Question Card
                    questionCard

                    // Options
                    optionsGrid

                    Spacer(minLength: 30)
                }
                .padding(.top, 8)
            }

            // Feedback Toast
            if showFeedback {
                VStack {
                    feedbackToast
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
            }
        }
        .animation(.spring(response: 0.3), value: viewModel.currentStreak)
    }

    // MARK: - Header
    private var quizHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Question counter
                Text("\(viewModel.currentQuestionIndex + 1)/\(viewModel.totalQuestions)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.12))
                            .frame(height: 10)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [Color.hikayaTeal, Color.hikayaTeal.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geometry.size.width * viewModel.progress), height: 10)
                            .animation(.easeInOut(duration: 0.4), value: viewModel.progress)
                    }
                }
                .frame(height: 10)

                // Score badge
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    Text("\(viewModel.totalScore)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                }
                .foregroundStyle(Color.hikayaOrange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.hikayaOrange.opacity(0.12))
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
                let score = viewModel.wordMastery[word.id]?.totalScore ?? 0

                HStack(spacing: 14) {
                    // Progress Ring
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.15), lineWidth: 4)
                            .frame(width: 48, height: 48)

                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                isMastered ? Color.green : Color.hikayaTeal,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 48, height: 48)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.4), value: progress)

                        if isMastered {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        } else {
                            Text("\(score)")
                                .font(.caption.bold())
                                .monospacedDigit()
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Word Mastery")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(isMastered ? "Mastered!" : "\(score)/100 points")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isMastered ? .green : .primary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                )
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Question Card
    private var questionCard: some View {
        Group {
            if let question = viewModel.currentQuestion {
                VStack(spacing: 20) {
                    Text(question.questionType == .arabicToEnglish ?
                         "What does this mean?" : "What's the Arabic word?")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.hikayaTeal)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.hikayaTeal.opacity(0.1))
                        )

                    Text(question.questionType == .arabicToEnglish ?
                         question.word.arabicText : question.word.englishMeaning)
                        .font(.system(size: 48, weight: .bold, design: .serif))
                        .minimumScaleFactor(0.4)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
                )
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Options Grid
    private var optionsGrid: some View {
        Group {
            if let question = viewModel.currentQuestion {
                VStack(spacing: 10) {
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

    // MARK: - Handle Selection
    private func handleSelection(_ option: String, isCorrect: Bool) {
        feedbackIsCorrect = isCorrect
        feedbackScore = isCorrect ? 10 : -20
        withAnimation(.spring(response: 0.3)) {
            showFeedback = true
        }

        viewModel.selectAnswer(option)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeOut(duration: 0.2)) {
                showFeedback = false
            }
        }
    }

    // MARK: - Feedback Toast
    private var feedbackToast: some View {
        HStack(spacing: 14) {
            Image(systemName: feedbackIsCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(feedbackIsCorrect ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text(feedbackIsCorrect ? "Correct!" : "Wrong!")
                    .font(.headline)
                    .foregroundStyle(feedbackIsCorrect ? .green : .red)

                Text(feedbackIsCorrect ? "+\(feedbackScore) points" : "\(feedbackScore) points")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(feedbackIsCorrect ? Color.hikayaOrange : .red.opacity(0.7))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: (feedbackIsCorrect ? Color.green : Color.red).opacity(0.2), radius: 16, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.top, 60)
    }
}

// MARK: - Quiz Complete View
struct QuizCompleteView: View {
    var viewModel: MyWordsViewModel
    var onDone: () -> Void
    @State private var isSaving = false
    
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
                Button {
                    isSaving = true
                    Task {
                        // Save progress before dismissing
                        await DataService.shared.saveWordMastery(viewModel.wordMastery)
                        print("💾 Quiz Complete: Saved word mastery before dismissing")
                        isSaving = false
                        onDone()
                    }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Done")
                        }
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
                .disabled(isSaving)
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
    let word: QuranWord
    let isMastered: Bool
    let progress: Double
    var isStarred: Bool = false
    var onToggleStar: (() -> Void)? = nil

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

            // Quran occurrence badge
            if word.occurrenceCount > 0 {
                Text("\(word.occurrenceCount)\u{00D7}")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.12))
                    )
            }

            // Star button
            Button {
                onToggleStar?()
            } label: {
                Image(systemName: isStarred ? "star.fill" : "star")
                    .foregroundStyle(isStarred ? .yellow : .gray.opacity(0.4))
                    .font(.title3)
            }
            .buttonStyle(.plain)

            if isMastered {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
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
    let word: QuranWord
    let isMastered: Bool
    let progress: Double
    @Environment(\.dismiss) private var dismiss
    
    // Audio & Bookmark states
    @State private var isPlayingAudio = false
    @State private var isBookmarked = false
    
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
                    
                    // Learning Progress Section
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
            
            // Badges
            HStack(spacing: 8) {
                if let pos = word.morphology.partOfSpeech {
                    MyWordBadge(text: word.posDisplayName, color: .blue)
                }
                if isMastered {
                    MyWordBadge(text: "Mastered", color: .green)
                } else {
                    MyWordBadge(text: "Learning", color: .orange)
                }
                MyWordBadge(text: "#\(word.rank)", color: .purple)
            }
            
            // Action Buttons
            HStack(spacing: 16) {
                Button(action: { playPronunciation() }) {
                    HStack(spacing: 6) {
                        Image(systemName: isPlayingAudio ? "speaker.wave.2.fill" : "speaker.wave.2")
                        Text("Listen")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundColor(.accentColor)
                    .cornerRadius(8)
                }
                
                Button(action: { toggleBookmark() }) {
                    HStack(spacing: 6) {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        Text(isBookmarked ? "Saved" : "Save")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isBookmarked ? Color.orange.opacity(0.1) : Color.gray.opacity(0.1))
                    .foregroundColor(isBookmarked ? .orange : .gray)
                    .cornerRadius(8)
                }
            }
            .padding(.top, 4)
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
            MyWordSectionHeader(title: "Root (المصدر)", icon: "arrow.branch")
            
            if let root = word.root?.arabic, !root.isEmpty {
                HStack(spacing: 12) {
                    Text(root)
                        .font(.system(size: 28, weight: .bold, design: .serif))
                    
                    if let meaning = word.root?.meaning {
                        Text(meaning)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
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
            MyWordSectionHeader(title: "Morphology (الصرف)", icon: "textformat")
            
            VStack(spacing: 8) {
                InfoRow(label: "Part of Speech", value: word.posDisplayName)
                
                if let root = word.root?.arabic, !root.isEmpty {
                    InfoRow(label: "Root", value: root, isRTL: true)
                }
                
                if let lemma = word.morphology.lemma {
                    InfoRow(label: "Lemma", value: lemma, isRTL: true)
                }
                
                if let buckwalter = word.buckwalter, !buckwalter.isEmpty {
                    InfoRow(label: "Transliteration", value: buckwalter)
                }
                
                InfoRow(label: "Quran Rank", value: "#\(word.rank)")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MyWordSectionHeader(title: "Learning Progress", icon: "chart.bar")
            
            HStack(spacing: 20) {
                StatItem(value: "\(Int(progress * 100))%", label: "Mastery", color: progressColor)
                StatItem(value: isMastered ? "Yes" : "No", label: "Mastered", color: isMastered ? .green : .gray)
            }
            
            HStack {
                Image(systemName: isMastered ? "star.fill" : "star")
                    .foregroundColor(isMastered ? .yellow : .gray)
                Text(isMastered ? "Mastered!" : "Keep practicing")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Examples Section
    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MyWordSectionHeader(title: "Examples", icon: "text.quote")
            
            if word.exampleArabic != nil || word.exampleEnglish != nil {
                VStack(spacing: 12) {
                    if let exampleArabic = word.exampleArabic {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(exampleArabic)
                                .font(.system(size: 18, weight: .medium, design: .serif))
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    
                    if let exampleEnglish = word.exampleEnglish {
                        Text(exampleEnglish)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
            } else {
                Text("No examples available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Actions
    @State private var audioPlayer: AVPlayer?
    
    private func playPronunciation() {
        guard !isPlayingAudio else { 
            // Stop if already playing
            audioPlayer?.pause()
            audioPlayer = nil
            isPlayingAudio = false
            return
        }
        
        // Play from audioURL if available
        if let audioURL = word.audioURL, let url = URL(string: audioURL) {
            isPlayingAudio = true
            audioPlayer = AVPlayer(url: url)
            audioPlayer?.play()
            
            // Reset after playback
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: audioPlayer?.currentItem, queue: .main) { _ in
                isPlayingAudio = false
                audioPlayer = nil
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

// MARK: - Stat Item
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
