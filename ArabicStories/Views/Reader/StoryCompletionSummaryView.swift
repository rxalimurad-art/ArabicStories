//
//  StoryCompletionSummaryView.swift
//  Arabicly
//  Story completion summary showing achievements, words unlocked, and stats
//

import SwiftUI

// MARK: - Completion Result Model

struct StoryCompletionResult {
    let story: Story
    let unlockedAchievements: [Achievement]
    let totalWordsInStory: Int
    let wordsUnlockedInSession: [QuranWord]
    let readingTime: TimeInterval
}

// MARK: - Story Completion Summary View

struct StoryCompletionSummaryView: View {
    let result: StoryCompletionResult
    let onDismiss: () -> Void
    
    @State private var showConfetti = false
    @State private var animateAchievements = false
    @State private var animateWords = false
    @State private var animateStats = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.hikayaCream,
                    Color.hikayaTeal.opacity(0.1),
                    Color.hikayaCream
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header - Story Completed
                    headerSection
                        .opacity(animateStats ? 1 : 0)
                        .offset(y: animateStats ? 0 : 20)
                    
                    // Achievements Unlocked Section
                    if !result.unlockedAchievements.isEmpty {
                        achievementsSection
                            .opacity(animateAchievements ? 1 : 0)
                            .offset(y: animateAchievements ? 0 : 20)
                    }
                    
                    // Words Unlocked Section
                    if !result.wordsUnlockedInSession.isEmpty {
                        wordsUnlockedSection
                            .opacity(animateWords ? 1 : 0)
                            .offset(y: animateWords ? 0 : 20)
                    }
                    
                    // Stats Summary
                    statsSection
                        .opacity(animateStats ? 1 : 0)
                        .offset(y: animateStats ? 0 : 20)
                    
                    // Continue Button
                    continueButton
                        .padding(.top, 8)
                        .opacity(animateStats ? 1 : 0)
                        .offset(y: animateStats ? 0 : 20)
                }
                .padding()
            }
            
            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            // Staggered animations
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                animateStats = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                animateAchievements = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                animateWords = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                showConfetti = true
            }
            
            // Hide confetti after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation {
                    showConfetti = false
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Success Icon
            ZStack {
                Circle()
                    .fill(Color.hikayaTeal.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Circle()
                    .fill(Color.hikayaTeal.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.hikayaTeal)
            }
            
            VStack(spacing: 8) {
                Text("Story Completed!")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)
                
                Text(result.story.title)
                    .font(.title3)
                    .foregroundStyle(Color.hikayaTeal)
                    .multilineTextAlignment(.center)
                
                if let arabicTitle = result.story.titleArabic {
                    Text(arabicTitle)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Achievements Section
    
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.title3)
                    .foregroundStyle(Color.hikayaOrange)
                
                Text("Achievements Unlocked")
                    .font(.headline.weight(.semibold))
                
                Spacer()
                
                Text("\(result.unlockedAchievements.count)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.hikayaOrange)
                    .clipShape(Capsule())
            }
            
            // Achievement Cards
            VStack(spacing: 12) {
                ForEach(result.unlockedAchievements) { achievement in
                    AchievementUnlockedCard(achievement: achievement)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - Words Unlocked Section
    
    private var wordsUnlockedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "textformat.abc")
                    .font(.title3)
                    .foregroundStyle(Color.green)
                
                Text("Words Unlocked")
                    .font(.headline.weight(.semibold))
                
                Spacer()
                
                Text("\(result.wordsUnlockedInSession.count)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .clipShape(Capsule())
            }
            
            // Words Grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                ForEach(result.wordsUnlockedInSession.prefix(12)) { word in
                    WordUnlockedCard(word: word)
                }
            }
            
            // Show "+X more" if there are more words
            if result.wordsUnlockedInSession.count > 12 {
                Text("+\(result.wordsUnlockedInSession.count - 12) more words")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.title3)
                    .foregroundStyle(Color.blue)
                
                Text("Reading Stats")
                    .font(.headline.weight(.semibold))
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                CompletionStatCard(
                    icon: "textformat.abc",
                    value: "\(result.totalWordsInStory)",
                    label: "Words in Story",
                    color: .blue
                )

                CompletionStatCard(
                    icon: "clock.fill",
                    value: formattedReadingTime,
                    label: "Reading Time",
                    color: .purple
                )

                CompletionStatCard(
                    icon: "flame.fill",
                    value: "\(result.wordsUnlockedInSession.count)",
                    label: "Words Learned",
                    color: .orange
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
    
    private var formattedReadingTime: String {
        let minutes = Int(result.readingTime) / 60
        let seconds = Int(result.readingTime) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    // MARK: - Continue Button
    
    private var continueButton: some View {
        Button(action: onDismiss) {
            HStack(spacing: 8) {
                Text("Continue")
                    .font(.headline.weight(.semibold))
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
            }
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
            .shadow(color: Color.hikayaTeal.opacity(0.3), radius: 10, x: 0, y: 4)
        }
    }
}

// MARK: - Achievement Unlocked Card

struct AchievementUnlockedCard: View {
    let achievement: Achievement
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 56, height: 56)
                
                Image(systemName: achievement.iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(categoryColor)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text(achievement.achievementDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(achievement.category.displayName)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(categoryColor.opacity(0.15))
                        .foregroundStyle(categoryColor)
                        .clipShape(Capsule())
                    
                    Text(achievement.rarity.displayName)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(rarityColor.opacity(0.15))
                        .foregroundStyle(rarityColor)
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
            
            // Checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(categoryColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(categoryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var categoryColor: Color {
        switch achievement.category {
        case .streak: return .orange
        case .vocabulary: return .green
        case .stories: return .blue
        case .time: return .cyan
        case .mastery: return .purple
        case .social: return .pink
        default: return .gray
        }
    }
    
    private var rarityColor: Color {
        switch achievement.rarity {
        case .common: return .gray
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
}

// MARK: - Word Unlocked Card

struct WordUnlockedCard: View {
    let word: QuranWord
    
    var body: some View {
        VStack(spacing: 8) {
            Text(word.arabicText)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            if let buckwalter = word.buckwalter {
                Text(buckwalter)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Text(word.englishMeaning)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.hikayaTeal)
                .lineLimit(1)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Completion Stat Card

struct CompletionStatCard: View {
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
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
        )
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { timeline in
            Canvas { context, size in
                for particle in particles {
                    var context = context
                    context.translateBy(x: particle.x, y: particle.y)
                    context.rotate(by: .degrees(particle.rotation))
                    
                    let rect = CGRect(x: -particle.size/2, y: -particle.size/2, 
                                    width: particle.size, height: particle.size)
                    context.fill(Path(rect), with: .color(particle.color))
                }
            }
        }
        .onAppear {
            createParticles()
            animateParticles()
        }
    }
    
    private func createParticles() {
        let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange, .pink, .cyan]
        particles = (0..<50).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                y: -20,
                size: CGFloat.random(in: 8...16),
                color: colors.randomElement()!,
                rotation: Double.random(in: 0...360),
                velocityY: CGFloat.random(in: 2...5),
                velocityX: CGFloat.random(in: -1...1),
                rotationSpeed: Double.random(in: -5...5)
            )
        }
    }
    
    private func animateParticles() {
        withAnimation(.linear(duration: 0.016).repeatForever(autoreverses: false)) {
            for index in particles.indices {
                particles[index].y += particles[index].velocityY
                particles[index].x += particles[index].velocityX
                particles[index].rotation += particles[index].rotationSpeed
                
                // Reset particle if it goes off screen
                if particles[index].y > UIScreen.main.bounds.height {
                    particles[index].y = -20
                    particles[index].x = CGFloat.random(in: 0...UIScreen.main.bounds.width)
                }
            }
        }
    }
}

struct ConfettiParticle {
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
    var rotation: Double
    var velocityY: CGFloat
    var velocityX: CGFloat
    var rotationSpeed: Double
}

// MARK: - Preview

#Preview {
    StoryCompletionSummaryView(
        result: StoryCompletionResult(
            story: Story(
                title: "The Wise Merchant",
                titleArabic: "التاجر الحكيم",
                storyDescription: "A story about wisdom",
                author: "Traditional",
                format: .mixed,
                difficultyLevel: 1
            ),
            unlockedAchievements: [
                Achievement(title: "Story Starter", achievementDescription: "Complete your first story", iconName: "book.open.fill", category: .stories, requirement: 1, rarity: .common),
                Achievement(title: "Word Seeker", achievementDescription: "Learn 5 Arabic words", iconName: "character", category: .vocabulary, requirement: 5, rarity: .rare)
            ],
            totalWordsInStory: 15,
            wordsUnlockedInSession: [
                QuranWord(id: "word-1", rank: 1, arabicText: "تَاجِر", arabicWithoutDiacritics: "تاجر", buckwalter: "tAjir", englishMeaning: "Merchant", root: nil, morphology: QuranMorphology(partOfSpeech: "N", passive: false), occurrenceCount: 10),
                QuranWord(id: "word-2", rank: 2, arabicText: "حَكِيم", arabicWithoutDiacritics: "حكيم", buckwalter: "HakIm", englishMeaning: "Wise", root: nil, morphology: QuranMorphology(partOfSpeech: "ADJ", passive: false), occurrenceCount: 15),
                QuranWord(id: "word-3", rank: 3, arabicText: "بَغْدَاد", arabicWithoutDiacritics: "بغداد", buckwalter: "bagodAd", englishMeaning: "Baghdad", root: nil, morphology: QuranMorphology(partOfSpeech: "PN", passive: false), occurrenceCount: 5)
            ],
            readingTime: 180
        ),
        onDismiss: {}
    )
}
