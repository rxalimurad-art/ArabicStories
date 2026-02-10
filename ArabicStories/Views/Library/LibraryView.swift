//
//  LibraryView.swift
//  Hikaya
//  Story library with grid layout, filters, and search
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @State private var viewModel = LibraryViewModel()
    @State private var showingImportSheet = false
    
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
                    
                    // Difficulty Filter
                    DifficultyFilterBar(
                        selectedLevel: viewModel.selectedDifficulty,
                        counts: viewModel.difficultyCounts
                    ) { level in
                        viewModel.setDifficulty(level)
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
                            hasFilters: viewModel.hasActiveFilters,
                            onImportTap: { showingImportSheet = true }
                        )
                    } else {
                        StoryGridView(
                            stories: viewModel.stories,
                            onBookmarkToggle: { story in
                                viewModel.toggleBookmark(story)
                            }
                        )
                    }
                }
            }
            .navigationTitle("Hikaya")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingImportSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundStyle(Color.hikayaTeal)
                    }
                }
            }
            .sheet(isPresented: $showingImportSheet) {
                JSONImportView()
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .environment(viewModel)
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
                    FilterChip(
                        title: "L\(level)",
                        subtitle: "\(counts[level] ?? 0)",
                        isSelected: selectedLevel == level,
                        color: difficultyColor(for: level)
                    ) {
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
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
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
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .shadow(color: color.opacity(isSelected ? 0.3 : 0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
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
    let onImportTap: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: hasFilters ? "magnifyingglass" : "book.closed")
                .font(.system(size: 60))
                .foregroundStyle(Color.hikayaTeal.opacity(0.5))
            
            Text(hasFilters ? "No stories found" : "No stories yet")
                .font(.title3.weight(.semibold))
            
            Text(hasFilters 
                 ? "Try adjusting your filters or search query"
                 : "Import stories from JSON or create your own")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            if !hasFilters {
                Button(action: onImportTap) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import Stories")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.hikayaTeal)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    LibraryView()
        .modelContainer(for: [
            Story.self,
            Word.self
        ], inMemory: true)
}
