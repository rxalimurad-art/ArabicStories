//
//  LibraryView.swift
//  Arabicly
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
                    
                    // Continue Reading Section
                    if let story = viewModel.continueReadingStory {
                        ContinueReadingCard(story: story, progress: viewModel.getStoryProgress(story.id))
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    }
                    
                    // Difficulty Filter with Lock Indicators
                    DifficultyFilterBar(
                        selectedLevel: viewModel.selectedDifficulty,
                        maxUnlockedLevel: viewModel.maxUnlockedLevel,
                        counts: viewModel.difficultyCounts,
                        onSelect: { level in
                            if let level = level, viewModel.isLevelLocked(level) {
                                viewModel.showLockedLevelAlert = true
                                viewModel.lockedLevelTapped = level
                            } else if viewModel.canAccessLevel(level ?? 1) {
                                viewModel.setDifficulty(level)
                            }
                        }
                    )
                    .padding(.horizontal)
                    
                    // Progress to unlock next level
                    if !viewModel.hasUnlockedLevel2 {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.hikayaOrange)
                            
                            Text(viewModel.unlockProgressText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text("\(viewModel.completedLevel1Stories)/\(viewModel.totalLevel1Stories)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.hikayaTeal)
                        }
                        .padding(.horizontal)
                        .padding(.top, 6)
                    }
                    
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
                            maxUnlockedLevel: viewModel.maxUnlockedLevel
                        )
                    }
                }
            }
            .navigationTitle("Arabicly")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    LevelBadge(level: viewModel.maxUnlockedLevel)
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .onAppear {
                // Refresh when returning from story reader
                Task {
                    await viewModel.refresh()
                }
            }
            .alert("🎉 Level 2 Unlocked!", isPresented: $viewModel.showLevelUnlockAlert) {
                Button("Continue", role: .cancel) {
                    viewModel.showLevelUnlockAlert = false
                }
            } message: {
                Text("Congratulations! You've completed all Level 1 stories. You can now read full Arabic stories.")
            }
            .alert("Keep Going! 🎯", isPresented: $viewModel.showLockedLevelAlert) {
                Button("Continue Reading", role: .cancel) {
                    viewModel.showLockedLevelAlert = false
                }
            } message: {
                Text(viewModel.lockedLevelMessage)
            }
        }
        .environment(viewModel)
    }
}

// MARK: - Level Badge

struct LevelBadge: View {
    let level: Int
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "crown.fill")
                .font(.system(size: 14, weight: .semibold))
            Text("Level \(level)")
                .font(.subheadline.weight(.bold))
        }
        .foregroundStyle(levelColor )
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
//        .background(
//            Capsule()
//                .fill(levelColor)
//        )
    }
    
    private var levelColor: Color {
        switch level {
        case 1: return .green
        case 2: return Color.hikayaTeal
        case 3: return .blue
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }
}

// MARK: - Continue Reading Card

struct ContinueReadingCard: View {
    let story: Story
    let progress: StoryProgress?
    
    private var readingProgress: Double {
        progress?.readingProgress ?? 0.0
    }
    
    var body: some View {
        NavigationLink(value: story) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                        Text("Continue Reading")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.hikayaTeal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.hikayaTeal.opacity(0.15))
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    Text("\(Int(readingProgress * 100))%")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 12) {
                    // Story Cover
                    StoryCoverImage(url: story.coverImageURL)
                        .frame(width: 60, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(story.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Text(story.author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 6)
                                
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.hikayaTeal)
                                    .frame(width: geometry.size.width * readingProgress, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Level Unlock Progress Card

struct LevelUnlockProgressCard: View {
    let progress: Double
    let storiesCompleted: Int
    let totalStories: Int
    let remainingStories: Int
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unlock Level 2")
                        .font(.headline.weight(.semibold))
                    
                    if remainingStories > 0 {
                        Text("Complete \(remainingStories) more story\(remainingStories == 1 ? "" : "ies") to unlock full Arabic stories")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else {
                        Text("All Level 1 stories completed! Level 2 unlocked!")
                            .font(.caption)
                            .foregroundStyle(Color.hikayaTeal)
                            .lineLimit(2)
                    }
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
                Text("\(storiesCompleted) of \(totalStories) stories completed")
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
                        // Always call onSelect - let parent handle locked state
                        onSelect(level)
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
//            if hasActiveFilters {
//                Button(action: onClearFilters) {
//                    HStack(spacing: 4) {
//                        Image(systemName: "xmark")
//                        Text("Clear")
//                            .font(.subheadline)
//                    }
//                    .foregroundStyle(Color.hikayaOrange)
//                }
//            }
        }
    }
}

// MARK: - Story List View (2-Column Layout)

struct StoryGridView: View {
    let stories: [Story]
    let maxUnlockedLevel: Int
    @Environment(LibraryViewModel.self) private var viewModel
    
    // Split stories into pairs for 2-column layout
    private var storyPairs: [[Story]] {
        let pairs = stride(from: 0, to: stories.count, by: 2).map { index in
            Array(stories[index..<min(index + 2, stories.count)])
        }
        print("📱 StoryGridView: Rendering \(stories.count) stories in \(pairs.count) rows")
        return pairs
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(Array(storyPairs.enumerated()), id: \.offset) { index, pair in
                    HStack(spacing: 16) {
                        ForEach(pair) { story in
                            let progress = viewModel.getStoryProgress(story.id)
                            NavigationLink(value: story) {
                                StoryCard(story: story, progress: progress)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Add empty placeholder if odd number of stories
                        if pair.count == 1 {
                            Color.clear
                                .frame(maxWidth: .infinity)
                        }
                    }
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
    let progress: StoryProgress?
    
    private var isCompleted: Bool {
        progress?.isCompleted ?? false
    }
    
    private var isBookmarked: Bool {
        progress?.isBookmarked ?? false
    }
    
    private var readingProgress: Double {
        progress?.readingProgress ?? 0.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover Image
            ZStack(alignment: .topTrailing) {
                StoryCoverImage(url: story.coverImageURL)
                    .frame(height: 140)
                
                // Completed Badge
                if isCompleted {
                    CompletionBadge()
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                
                // Bookmark Badge
                if isBookmarked {
                    Image(systemName: "bookmark.fill")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Color.hikayaOrange)
                        .clipShape(Circle())
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
                
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
                
                // Arabic word count
                let wordCount = story.arabicWordCount
                if wordCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "character.book.closed")
                            .font(.caption2)
                        Text("\(wordCount) words")
                            .font(.caption2)
                    }
                    .foregroundStyle(Color.hikayaTeal)
                    .padding(.top, 2)
                }
                
                // Progress
                if readingProgress > 0 {
                    if isCompleted {
                        // Show full progress bar for completed
                        StoryProgressBar(progress: 1.0)
                            .padding(.top, 4)
                    } else {
                        // Show partial progress
                        StoryProgressBar(progress: readingProgress)
                            .padding(.top, 4)
                    }
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

// MARK: - Completion Badge

struct CompletionBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
            Text("Done")
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
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
                            .aspectRatio(contentMode: .fill)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        VStack(alignment: .leading, spacing: 2) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [Color.hikayaTeal, Color.hikayaTeal.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geometry.size.width * progress, 4), height: 6)
                }
            }
            .frame(height: 6)
            
            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
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
        
        // Create mixed content segments - simplified format: just text with linkedWordIds
        let segments = [
            MixedContentSegment(
                index: 0,
                text: "Once upon a time, there was a young man named Ahmad who wanted to find true peace in his life. He began his journey by turning to اللَّهُ (Allah), the Most Merciful, and calling upon his رَبِّ (Rabb) for guidance.",
                linkedWordIds: [words[0].id.uuidString, words[1].id.uuidString]
            ),
            MixedContentSegment(
                index: 1,
                text: "Every day, Ahmad would open the الْكِتَابُ (Al-Kitab) — the holy book sent by Allah — and read its beautiful verses. He learned that السَّلَامُ (As-Salaam) (peace) comes only through submission to the One God.",
                linkedWordIds: [words[2].id.uuidString, words[3].id.uuidString]
            )
        ]
        
        return Story(
            title: "Ahmad's Journey to Peace",
            titleArabic: "رحلة أحمد إلى السلام",
            storyDescription: "A beginner-friendly story about Ahmad's spiritual journey, introducing essential Arabic vocabulary.",
            storyDescriptionArabic: "قصة مناسبة للمبتدئين عن الرحلة الروحية لأحمد، تقدم مفردات عربية أساسية.",
            author: "Arabicly",
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
