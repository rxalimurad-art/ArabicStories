//
//  WordQuizView.swift
//  Arabicly
//  Interactive word quiz with scoring
//

import SwiftUI

struct WordQuizView: View {
    @State private var viewModel = WordQuizViewModel()
    @State private var showSettings = false
    @State private var showResults = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.hikayaCream.ignoresSafeArea()
                
                Group {
                    if viewModel.isLoading {
                        loadingView
                    } else if viewModel.isSessionComplete {
                        QuizResultsView(
                            results: viewModel.getResults(),
                            onRestart: { viewModel.restartQuiz() },
                            onExit: { dismiss() }
                        )
                    } else if let question = viewModel.currentQuestion {
                        questionView(question)
                    } else {
                        startView
                    }
                }
            }
            .navigationTitle("Word Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Exit") {
                        viewModel.endSession()
                        dismiss()
                    }
                }
                
                if viewModel.session != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 12) {
                            // Score
                            Text("\(viewModel.totalScore)")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.hikayaTeal)
                                )
                            
                            // Streak
                            if viewModel.currentStreak > 2 {
                                HStack(spacing: 4) {
                                    Image(systemName: "flame.fill")
                                        .foregroundStyle(.orange)
                                    Text("\(viewModel.currentStreak)")
                                        .font(.headline)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Start View
    
    private var startView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "checkmark.circle.badge.questionmark.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.hikayaTeal)
            
            VStack(spacing: 12) {
                Text("Word Quiz")
                    .font(.largeTitle.bold())
                
                Text("Test your vocabulary knowledge")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Features
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "plus.circle.fill", color: .green, text: "+10 points for correct answer")
                FeatureRow(icon: "bolt.circle.fill", color: .orange, text: "+5 bonus for fast answers")
                FeatureRow(icon: "minus.circle.fill", color: .red, text: "-5 points for wrong answers")
                FeatureRow(icon: "repeat.circle.fill", color: .blue, text: "Keep practicing until mastery")
            }
            .padding()
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 10)
            .padding(.horizontal)
            
            Spacer()
            
            Button {
                Task {
                    await viewModel.startQuiz()
                }
            } label: {
                Label("Start Quiz", systemImage: "play.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.hikayaTeal)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading quiz...")
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Question View
    
    private func questionView(_ question: QuizQuestion) -> some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.hikayaTeal)
                        .frame(width: geo.size.width * viewModel.progress, height: 8)
                }
            }
            .frame(height: 8)
            .padding(.horizontal)
            .padding(.top)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Question number
                    Text("Question \(viewModel.questionsAnswered + 1)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.top)
                    
                    // Question card
                    questionCard(question)
                    
                    // Options
                    optionsGrid(question)
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
        }
    }
    
    private func questionCard(_ question: QuizQuestion) -> some View {
        VStack(spacing: 16) {
            switch question.questionType {
            case .arabicToEnglish:
                Text(question.word.arabicText)
                    .font(.custom("NotoNaskhArabic", size: 48))
                    .multilineTextAlignment(.center)
                
                if let transliteration = question.word.transliteration {
                    Text(transliteration)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Text("Select the meaning")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                
            case .englishToArabic:
                Text(question.word.englishMeaning)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                
                Text("Select the Arabic word")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                
            case .audioToText:
                // Audio question placeholder
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.hikayaTeal)
                
                Text("Listen and select the meaning")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 5)
        )
    }
    
    private func optionsGrid(_ question: QuizQuestion) -> some View {
        LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
            ForEach(question.options, id: \.self) { option in
                OptionButton(
                    text: option,
                    isSelected: viewModel.selectedOption == option,
                    isCorrect: viewModel.showResult ? option == question.correctAnswer : nil,
                    showResult: viewModel.showResult
                ) {
                    if !viewModel.showResult {
                        viewModel.selectAnswer(option)
                    }
                }
            }
        }
    }
}

// MARK: - Option Button

struct OptionButton: View {
    let text: String
    let isSelected: Bool
    let isCorrect: Bool?      // nil = not showing result yet
    let showResult: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.body.weight(isSelected || showResult ? .semibold : .regular))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                if showResult {
                    Image(systemName: iconName)
                        .foregroundStyle(iconColor)
                        .font(.title3.weight(.bold))
                }
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(backgroundColor)
            .foregroundStyle(textColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(showResult)
    }
    
    private var backgroundColor: Color {
        if showResult {
            if isCorrect == true {
                return Color.green.opacity(0.15)
            } else if isSelected && isCorrect == false {
                return Color.red.opacity(0.15)
            }
        }
        return isSelected ? Color.hikayaTeal.opacity(0.1) : Color.white
    }
    
    private var textColor: Color {
        if showResult {
            if isCorrect == true {
                return .green
            } else if isSelected && isCorrect == false {
                return .red
            }
        }
        return .primary
    }
    
    private var borderColor: Color {
        if showResult {
            if isCorrect == true {
                return .green
            } else if isSelected && isCorrect == false {
                return .red
            }
        }
        return isSelected ? Color.hikayaTeal : Color.gray.opacity(0.3)
    }
    
    private var borderWidth: CGFloat {
        isSelected || (showResult && isCorrect == true) ? 2 : 1
    }
    
    private var iconName: String {
        if isCorrect == true {
            return "checkmark.circle.fill"
        } else if isSelected {
            return "xmark.circle.fill"
        }
        return ""
    }
    
    private var iconColor: Color {
        isCorrect == true ? .green : .red
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

// MARK: - Results View

struct QuizResultsView: View {
    let results: QuizResults?
    let onRestart: () -> Void
    let onExit: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.yellow)
                    
                    Text("Quiz Complete!")
                        .font(.largeTitle.bold())
                }
                .padding(.top, 40)
                
                if let results = results {
                    // Score Card
                    VStack(spacing: 16) {
                        Text("\(results.totalScore)")
                            .font(.system(size: 72, weight: .bold))
                            .foregroundStyle(Color.hikayaTeal)
                        
                        Text("Total Score")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.05), radius: 10)
                    .padding(.horizontal)
                    
                    // Stats Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(title: "Correct", value: "\(results.correctCount)", color: .green)
                        StatCard(title: "Wrong", value: "\(results.wrongCount)", color: .red)
                        StatCard(title: "Accuracy", value: String(format: "%.0f%%", results.accuracy * 100), color: .blue)
                        StatCard(title: "Best Streak", value: "\(results.bestStreak)", color: .orange)
                    }
                    .padding(.horizontal)
                    
                    // Mastered Words
                    if !results.masteredWords.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("🎉 Mastered Words")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Text("\(results.masteredWords.count) words mastered!")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Buttons
                VStack(spacing: 12) {
                    Button {
                        onRestart()
                    } label: {
                        Label("Quiz Again", systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.hikayaTeal)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    Button {
                        onExit()
                    } label: {
                        Text("Back to Library")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .background(Color.hikayaCream.ignoresSafeArea())
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }
}

#Preview {
    WordQuizView()
}
