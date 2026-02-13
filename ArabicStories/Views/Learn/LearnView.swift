//
//  LearnView.swift
//  Hikaya
//  Combined Words & Quiz tab with story-based locking
//

import SwiftUI

struct LearnView: View {
    @State private var viewModel = WordsQuizViewModel()
    @State private var selectedWord: Word?
    @State private var showFilters = false
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isQuizActive {
                    QuizSessionView(viewModel: viewModel)
                } else {
                    WordsListWithQuizView(
                        viewModel: viewModel,
                        selectedWord: $selectedWord,
                        searchQuery: $viewModel.searchQuery
                    )
                }
            }
            .navigationTitle("Learn")
            .sheet(item: $selectedWord) { word in
                WordDetailSheet(word: word, viewModel: viewModel)
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
}

// MARK: - Words List with Quiz CTA

struct WordsListWithQuizView: View {
    var viewModel: WordsQuizViewModel
    @Binding var selectedWord: Word?
    @Binding var searchQuery: String
    
    var body: some View {
        List {
            // Quiz CTA Section
            if !viewModel.quizWords.isEmpty {
                Section {
                    QuizCTACard(
                        unlockedCount: viewModel.unlockedWords.count,
                        quizCount: viewModel.quizWords.count,
                        onStartQuiz: {
                            Task { await viewModel.startQuiz() }
                        }
                    )
                }
            }
            
            // Stats Section
            Section {
                StatsRow(
                    total: viewModel.allWords.count,
                    unlocked: viewModel.unlockedWords.count,
                    mastered: viewModel.wordStats.values.filter(\.isMastered).count
                )
            }
            
            // Search Bar
            Section {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search words...", text: $searchQuery)
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            // Words List
            Section(header: Text("Words")) {
                ForEach(viewModel.filteredWords) { word in
                    WordRowWithLock(
                        word: word,
                        stat: viewModel.wordStats[word.id],
                        isUnlocked: viewModel.isWordUnlocked(word),
                        lockReason: viewModel.getLockReason(word)
                    )
                    .onTapGesture {
                        if viewModel.isWordUnlocked(word) {
                            selectedWord = word
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}

// MARK: - Quiz CTA Card

struct QuizCTACard: View {
    let unlockedCount: Int
    let quizCount: Int
    let onStartQuiz: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                Spacer()
                Text("\(quizCount) words ready")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.2))
                    .clipShape(Capsule())
            }
            
            Text("Ready to practice?")
                .font(.headline)
            
            Text("Test your knowledge of \(unlockedCount) unlocked words")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button(action: onStartQuiz) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Quiz")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Stats Row

struct StatsRow: View {
    let total: Int
    let unlocked: Int
    let mastered: Int
    
    var body: some View {
        HStack(spacing: 16) {
            StatBadge(value: total, label: "Total", color: .gray)
            StatBadge(value: unlocked, label: "Unlocked", color: .blue)
            StatBadge(value: mastered, label: "Mastered", color: .green)
        }
        .padding(.vertical, 8)
    }
}

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

// MARK: - Word Row with Lock

struct WordRowWithLock: View {
    let word: Word
    let stat: WordStat?
    let isUnlocked: Bool
    let lockReason: String?
    
    var body: some View {
        HStack(spacing: 16) {
            // Mastery Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                    .frame(width: 44, height: 44)
                
                if isUnlocked, let stat = stat {
                    Circle()
                        .trim(from: 0, to: Double(stat.masteryPercentage) / 100)
                        .stroke(
                            masteryColor(for: stat.masteryPercentage),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(stat.masteryPercentage)")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Word Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(word.arabicText)
                        .font(.title3.bold())
                    
                    if isUnlocked, let pos = word.partOfSpeech {
                        Text(pos.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                
                if isUnlocked {
                    Text(word.englishMeaning)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let reason = lockReason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            
            Spacer()
            
            if !isUnlocked {
                Image(systemName: "lock.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange.opacity(0.8))
            } else if stat?.isMastered == true {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            }
        }
        .opacity(isUnlocked ? 1.0 : 0.6)
    }
    
    private func masteryColor(for percentage: Int) -> Color {
        switch percentage {
        case 0..<30: return .red
        case 30..<70: return .orange
        case 70..<100: return .yellow
        default: return .green
        }
    }
}

// MARK: - Word Detail Sheet

struct WordDetailSheet: View {
    let word: Word
    let viewModel: WordsQuizViewModel
    @Environment(\.dismiss) private var dismiss
    
    var stat: WordStat? {
        viewModel.wordStats[word.id]
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Arabic Word
                    Text(word.arabicText)
                        .font(.system(size: 48, weight: .bold))
                        .multilineTextAlignment(.center)
                    
                    // English Meaning
                    Text(word.englishMeaning)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    
                    // Mastery Progress
                    if let stat = stat {
                        MasteryProgressCard(stat: stat)
                    }
                    
                    // Details
                    if let pos = word.partOfSpeech {
                        LearnDetailRow(icon: "textformat", title: "Part of Speech", value: pos.rawValue)
                    }
                    
                    if let root = word.rootLetters {
                        LearnDetailRow(icon: "link", title: "Root Letters", value: root)
                    }
                    
                    LearnDetailRow(icon: "chart.bar", title: "Difficulty", value: "\(word.difficulty)/5")
                }
                .padding()
            }
            .navigationTitle("Word Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct MasteryProgressCard: View {
    let stat: WordStat
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: Double(stat.masteryPercentage) / 100)
                    .stroke(
                        masteryColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text("\(stat.masteryPercentage)%")
                        .font(.title.bold())
                    if stat.isMastered {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    }
                }
            }
            
            Text(stat.isMastered ? "Mastered!" : "Keep practicing!")
                .font(.headline)
                .foregroundStyle(stat.isMastered ? .green : .secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var masteryColor: Color {
        switch stat.masteryPercentage {
        case 0..<30: return .red
        case 30..<70: return .orange
        case 70..<100: return .yellow
        default: return .green
        }
    }
}

struct LearnDetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            Text(title)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Quiz Session View

struct QuizSessionView: View {
    var viewModel: WordsQuizViewModel
    @State private var showExitConfirmation = false
    
    var body: some View {
        VStack(spacing: 20) {
            if viewModel.isSessionComplete {
                LearnQuizResultsView(viewModel: viewModel)
            } else if let question = viewModel.currentQuestion {
                // Progress
                ProgressView(value: viewModel.progress)
                    .padding(.horizontal)
                
                Text("Score: \(viewModel.totalScore)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Question Card
                VStack(spacing: 24) {
                    Text("What does this mean?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text(question.word.arabicText)
                        .font(.system(size: 40, weight: .bold))
                        .minimumScaleFactor(0.5)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                
                Spacer()
                
                // Options Grid - NOW WITH 4 OPTIONS
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(question.options, id: \.self) { option in
                        LearnOptionButton(
                            text: option,
                            isSelected: viewModel.selectedOption == option,
                            isCorrect: viewModel.showResult && option == question.correctAnswer,
                            isWrong: viewModel.showResult && viewModel.selectedOption == option && option != question.correctAnswer,
                            action: {
                                if !viewModel.showResult {
                                    viewModel.selectAnswer(option)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
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
            }
        } message: {
            Text("Your progress will be saved.")
        }
    }
}

// MARK: - Option Button

struct LearnOptionButton: View {
    let text: String
    let isSelected: Bool
    let isCorrect: Bool
    let isWrong: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.headline)
                .foregroundStyle(foregroundColor)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 80)
                .padding()
                .background(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isSelected)
    }
    
    private var foregroundColor: Color {
        if isCorrect { return .white }
        if isWrong { return .white }
        if isSelected { return .white }
        return .primary
    }
    
    private var backgroundColor: Color {
        if isCorrect { return .green }
        if isWrong { return .red }
        if isSelected { return .blue }
        return Color(.secondarySystemBackground)
    }
    
    private var borderColor: Color {
        if isCorrect { return .green }
        if isWrong { return .red }
        if isSelected { return .blue }
        return Color.clear
    }
}

// MARK: - Quiz Results View

struct LearnQuizResultsView: View {
    var viewModel: WordsQuizViewModel
    
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
                ResultStat(value: "\(viewModel.bestStreak)", label: "Best Streak")
            }
            
            Button("Back to Words") {
                viewModel.endQuiz()
            }
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

// MARK: - Preview

#Preview {
    LearnView()
}
