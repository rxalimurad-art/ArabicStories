//
//  LibraryView.swift
//  Hikaya
//  Story library with grid layout, filters, and level management
//

import SwiftUI

struct LibraryView: View {
    @State private var viewModel = LibraryViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.hikayaBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Bar
                    SearchBar(text: $viewModel.searchQuery) {
                        viewModel.search(query: viewModel.searchQuery)
                    }
                    .padding()
                    
                    // Level Progress Card (show when Level 2 is locked)
                    if !viewModel.hasUnlockedLevel2 {
                        LevelUnlockProgressCard(
                            progress: viewModel.vocabularyProgressToLevel2,
                            wordsLearned: viewModel.vocabularyProgressPercentage * 20 / 100,
                            wordsNeeded: 20,
                            remainingWords: viewModel.vocabularyRemainingForLevel2
                        )
                        .padding(.horizontal)
                    }
                    
                    // Difficulty Filter with Lock Indicators
                    DifficultyFilterBar(
                        selectedLevel: viewModel.selectedDifficulty,
                        maxUnlockedLevel: viewModel.maxUnlockedLevel,
                        counts: viewModel.difficultyCounts
                    ) { level in
                        if viewModel.canAccessLevel(level ?? 1) {
                            viewModel.setDifficulty(level)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Filter/Sort Bar
                    FilterSortBar(
                        sortOption: viewModel.selectedSortOption,
                        hasActiveFilters: viewModel.hasActiveFilters,
                        onSortSelected: { option in
                            viewModel.setSortOption(option)
                        },
                        onClearFilters: {
                            viewModel.clearFilters()
                        }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Content
                    if viewModel.isLoading {
                        LoadingView()
                    } else if viewModel.stories.isEmpty {
                        EmptyLibraryView(
                            hasFilters: viewModel.hasActiveFilters
                        )
                    } else {
                        StoryGridView(
                            stories: viewModel.stories,
                            maxUnlockedLevel: viewModel.maxUnlockedLevel,
                            onBookmarkToggle: { story in
                                Task {
                                    await viewModel.toggleBookmark(story)
                                }
                            }
                        )
                    }
                }
            }
            .navigationTitle("Hikaya")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.refresh()
            }
            .alert("🎉 Level 2 Unlocked!", isPresented: $viewModel.showLevelUnlockAlert) {
                Button("Continue", role: .cancel) {
                    viewModel.showLevelUnlockAlert = false
                }
            } message: {
                Text("Congratulations! You've learned enough Arabic vocabulary to start reading full Arabic stories.")
            }
        }
        .environment(viewModel)
    }
}

// MARK: - Level Unlock Progress Card

struct LevelUnlockProgressCard: View {
    let progress: Double
    let wordsLearned: Int
    let wordsNeeded: Int
    let remainingWords: Int
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unlock Level 2")
                        .font(.headline.weight(.semibold))
                    
                    Text("Learn \(remainingWords) more word\(remainingWords == 1 ? "" : "s") to unlock full Arabic stories")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Progress Ring
                ZStack {
                    Circle()
                        .stroke(Color.hikayaTeal.opacity(0.2), lineWidth: 4)
                        .frame(width: 44, height: 44)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.hikayaTeal, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.hikayaTeal)
                }
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [Color.hikayaTeal, Color.hikayaTeal.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
            
            HStack {
                Text("\(wordsLearned) of \(wordsNeeded) words learned")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.hikayaTeal.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    let onSearch: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search stories, authors, words...", text: $text)
                .submitLabel(.search)
                .onSubmit(onSearch)
            
            if !text.isEmpty {
                Button {
                    text = ""
                    onSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Difficulty Filter Bar

struct DifficultyFilterBar: View {
    let selectedLevel: Int?
    let maxUnlockedLevel: Int
    let counts: [Int: Int]
    let onSelect: (Int?) -> Void
    
    private let levels = [1, 2, 3, 4, 5]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // All button
                FilterChip(
                    title: "All",
                    isSelected: selectedLevel == nil,
                    color: .hikayaTeal
                ) {
                    onSelect(nil)
                }
                
                ForEach(levels, id: \.self) { level in
                    let isLocked = level > maxUnlockedLevel
                    FilterChip(
                        title: "L\(level)",
                        isSelected: selectedLevel == level,
                        color: difficultyColor(for: level),
                        isLocked: isLocked
                    ) {
                        if !isLocked {
                            onSelect(level)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
    }
    
    private func difficultyColor(for level: Int) -> Color {
        switch level {
        case 1: return .green
        case 2: return .hikayaTeal
        case 3: return .blue
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    let color: Color
    var isLocked: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                }
                
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .medium))
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.systemBackground))
            .foregroundStyle(isSelected ? .white : (isLocked ? .secondary : .primary))
            .clipShape(Capsule())
            .shadow(color: color.opacity(isSelected ? 0.3 : 0.05), radius: 4, x: 0, y: 2)
            .overlay(
                Capsule()
                    .stroke(isLocked ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .opacity(isLocked ? 0.6 : 1)
    }
}

// MARK: - Filter/Sort Bar

struct FilterSortBar: View {
    let sortOption: SortOption
    let hasActiveFilters: Bool
    let onSortSelected: (SortOption) -> Void
    let onClearFilters: () -> Void
    
    @State private var showingSortMenu = false
    
    var body: some View {
        HStack {
            // Sort Button
            Menu {
                ForEach(SortOption.allCases) { option in
                    Button {
                        onSortSelected(option)
                    } label: {
                        Label(option.displayName, systemImage: option.icon)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text("Sort: \(sortOption.displayName)")
                        .font(.subheadline)
                }
                .foregroundStyle(Color.hikayaTeal)
            }
            
            Spacer()
            
            // Clear Filters Button
            if hasActiveFilters {
                Button(action: onClearFilters) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("Clear")
                            .font(.subheadline)
                    }
                    .foregroundStyle(Color.hikayaOrange)
                }
            }
        }
    }
}

// MARK: - Story Grid View

struct StoryGridView: View {
    let stories: [Story]
    let maxUnlockedLevel: Int
    let onBookmarkToggle: (Story) -> Void
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(stories) { story in
                    NavigationLink(value: story) {
                        StoryCard(story: story) {
                            onBookmarkToggle(story)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationDestination(for: Story.self) { story in
            StoryReaderView(story: story)
        }
    }
}

// MARK: - Story Card

struct StoryCard: View {
    let story: Story
    let onBookmarkTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover Image
            ZStack(alignment: .topTrailing) {
                StoryCoverImage(url: story.coverImageURL)
                    .frame(height: 140)
                
                // Format Badge
                if story.format == .mixed {
                    FormatBadge(text: "Level 1", color: .green)
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                
                // Bookmark Button
                Button(action: onBookmarkTap) {
                    Image(systemName: story.isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.title3)
                        .foregroundStyle(story.isBookmarked ? Color.hikayaOrange : Color.white)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(8)
                
                // Difficulty Badge
                DifficultyBadge(level: story.difficultyLevel)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(story.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(story.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Vocabulary count for mixed format
                if story.format == .mixed, let words = story.words {
                    HStack(spacing: 4) {
                        Image(systemName: "character.book.closed")
                            .font(.caption2)
                        Text("\(story.learnedVocabularyCount)/\(words.count) words")
                            .font(.caption2)
                    }
                    .foregroundStyle(Color.hikayaTeal)
                    .padding(.top, 2)
                }
                
                // Progress
                if story.readingProgress > 0 {
                    StoryProgressBar(progress: story.readingProgress)
                        .padding(.top, 4)
                }
            }
            .padding(12)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Format Badge

struct FormatBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.9))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}

// MARK: - Story Cover Image

struct StoryCoverImage: View {
    let url: String?
    
    var body: some View {
        Group {
            if let urlString = url,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        skeleton
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipped()
    }
    
    private var skeleton: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemGray5))
            .shimmering()
    }
    
    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.hikayaTeal.opacity(0.3), Color.hikayaOrange.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundStyle(Color.hikayaTeal.opacity(0.5))
        }
    }
}

// MARK: - Difficulty Badge

struct DifficultyBadge: View {
    let level: Int
    
    var body: some View {
        Text("L\(level)")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.9))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
    
    private var color: Color {
        switch level {
        case 1: return .green
        case 2: return .hikayaTeal
        case 3: return .blue
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }
}

// MARK: - Story Progress Bar

struct StoryProgressBar: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(.systemGray5))
                    .frame(height: 4)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.hikayaTeal)
                    .frame(width: geometry.size.width * progress, height: 4)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading stories...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Empty Library View

struct EmptyLibraryView: View {
    let hasFilters: Bool
    @State private var isSeeding = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: hasFilters ? "magnifyingglass" : "book.closed")
                .font(.system(size: 60))
                .foregroundStyle(Color.hikayaTeal.opacity(0.5))
            
            Text(hasFilters ? "No stories found" : "No stories yet")
                .font(.title3.weight(.semibold))
            
            Text(hasFilters 
                 ? "Try adjusting your filters or search query"
                 : "Stories will appear here when available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            if !hasFilters {
                Button {
                    Task {
                        isSeeding = true
                        await seedSampleStories()
                        isSeeding = false
                    }
                } label: {
                    if isSeeding {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Label("Add Sample Story", systemImage: "plus.circle")
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
                .disabled(isSeeding)
            }
        }
        .padding()
        .frame(maxHeight: .infinity)
    }
    
    private func seedSampleStories() async {
        // Seed a Level 1 mixed format story
        let sampleStory = createSampleLevel1Story()
        
        do {
            try await FirebaseService.shared.saveStory(sampleStory)
        } catch {
            print("Failed to seed: \(error)")
        }
    }
    
    private func createSampleLevel1Story() -> Story {
        // Create vocabulary words
        let words = [
            Word(arabicText: "اللَّهُ", transliteration: "Allah", englishMeaning: "God", difficulty: 1),
            Word(arabicText: "رَبِّ", transliteration: "Rabb", englishMeaning: "Lord", difficulty: 1),
            Word(arabicText: "الْكِتَابُ", transliteration: "Al-Kitab", englishMeaning: "The Book", difficulty: 1),
            Word(arabicText: "السَّلَامُ", transliteration: "As-Salaam", englishMeaning: "Peace", difficulty: 1),
            Word(arabicText: "الصَّلَاةُ", transliteration: "As-Salah", englishMeaning: "Prayer", difficulty: 1)
        ]
        
        // Create mixed content segments
        let segments = [
            MixedContentSegment(
                index: 0,
                contentParts: [
                    .text("Once upon a time, there was a young man named Ahmad who wanted to find true peace in his life. He began his journey by turning to "),
                    .arabicWord("اللَّهُ", wordId: words[0].id.uuidString, transliteration: "(Allah)"),
                    .text(", the Most Merciful, and calling upon his "),
                    .arabicWord("رَبِّ", wordId: words[1].id.uuidString, transliteration: "(Rabb)"),
                    .text(" for guidance.")
                ]
            ),
            MixedContentSegment(
                index: 1,
                contentParts: [
                    .text("Every day, Ahmad would open the "),
                    .arabicWord("الْكِتَابُ", wordId: words[2].id.uuidString, transliteration: "(Al-Kitab)"),
                    .text(" — the holy book sent by Allah — and read its beautiful verses. He learned that "),
                    .arabicWord("السَّلَامُ", wordId: words[3].id.uuidString, transliteration: "(As-Salaam)"),
                    .text(" (peace) comes only through submission to the One God.")
                ]
            )
        ]
        
        return Story(
            title: "Ahmad's Journey to Peace",
            titleArabic: "رحلة أحمد إلى السلام",
            storyDescription: "A beginner-friendly story about Ahmad's spiritual journey, introducing essential Arabic vocabulary.",
            storyDescriptionArabic: "قصة مناسبة للمبتدئين عن الرحلة الروحية لأحمد، تقدم مفردات عربية أساسية.",
            author: "Hikaya Learning",
            format: .mixed,
            difficultyLevel: 1,
            category: .religious,
            tags: ["beginner", "vocabulary", "spiritual"],
            coverImageURL: "https://images.unsplash.com/photo-1519817914152-22d216bb9170?w=800",
            mixedSegments: segments,
            words: words
        )
    }
}

// MARK: - Shimmer Effect Modifier

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.5),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + phase * geometry.size.width * 2)
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}



// MARK: - Preview

#Preview {
    LibraryView()
}
