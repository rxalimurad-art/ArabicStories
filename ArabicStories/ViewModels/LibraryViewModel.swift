//
//  LibraryViewModel.swift
//  Hikaya
//  ViewModel for the Story Library view
//

import Foundation


@Observable
class LibraryViewModel {
    // Dependencies
    private let dataService = DataService.shared
    
    // State
    var stories: [Story] = []
    var filteredStories: [Story] = []
    var isLoading = false
    var errorMessage: String?
    
    // Filter State
    var selectedDifficulty: Int? = nil
    var searchQuery = ""
    var selectedSortOption: SortOption = .newest
    var selectedCategory: StoryCategory? = nil
    
    // UI State
    var showFilters = false
    var showSortMenu = false
    
    // Tasks
    private var searchTask: Task<Void, Never>?
    
    init() {
        Task {
            await loadStories()
        }
    }
    
    // MARK: - Data Loading
    
    func loadStories() async {
        isLoading = true
        defer { isLoading = false }
        
        stories = await dataService.fetchStories(
            difficulty: selectedDifficulty,
            category: selectedCategory,
            searchQuery: searchQuery.isEmpty ? nil : searchQuery,
            sortBy: selectedSortOption
        )
        
        filteredStories = stories
    }
    
    func refresh() async {
        await loadStories()
    }
    
    // MARK: - Search
    
    func search(query: String) {
        searchQuery = query
        
        // Debounce search
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            await loadStories()
        }
    }
    
    // MARK: - Filtering
    
    func setDifficulty(_ level: Int?) {
        selectedDifficulty = level
        Task {
            await loadStories()
        }
    }
    
    func setCategory(_ category: StoryCategory?) {
        selectedCategory = category
        Task {
            await loadStories()
        }
    }
    
    func setSortOption(_ option: SortOption) {
        selectedSortOption = option
        Task {
            await loadStories()
        }
    }
    
    func clearFilters() {
        selectedDifficulty = nil
        selectedCategory = nil
        searchQuery = ""
        Task {
            await loadStories()
        }
    }
    
    // MARK: - Actions
    
    func toggleBookmark(_ story: Story) async {
        await dataService.toggleBookmark(story)
        await loadStories()
    }
    
    func deleteStory(_ story: Story) async {
        do {
            try await dataService.deleteStory(story)
            await loadStories()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Computed Properties
    
    var hasActiveFilters: Bool {
        selectedDifficulty != nil || selectedCategory != nil || !searchQuery.isEmpty
    }
    
    var storiesByDifficulty: [Int: [Story]] {
        Dictionary(grouping: stories) { $0.difficultyLevel }
    }
    
    var bookmarkedStories: [Story] {
        stories.filter { $0.isBookmarked }
    }
    
    var inProgressStories: [Story] {
        stories.filter { $0.isInProgress }.sorted { ($0.lastReadDate ?? .distantPast) > ($1.lastReadDate ?? .distantPast) }
    }
    
    var completedStories: [Story] {
        stories.filter { $0.isCompleted }
    }
    
    var difficultyCounts: [Int: Int] {
        Dictionary(grouping: stories) { $0.difficultyLevel }
            .mapValues { $0.count }
    }
}
