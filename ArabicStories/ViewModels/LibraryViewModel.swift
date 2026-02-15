//
//  LibraryViewModel.swift
//  Arabicly
//  ViewModel for the Story Library view with level management
//

import Foundation
import Combine

@Observable
class LibraryViewModel {
    // Dependencies
    private let dataService = DataService.shared
    
    // State
    var stories: [Story] = []
    var filteredStories: [Story] = []
    var storyProgress: [String: StoryProgress] = [:] // Key: storyId
    var isLoading = false
    var errorMessage: String?
    
    // Level Management
    var maxUnlockedLevel: Int = 1
    var storyProgressToLevel2: Double = 0.0
    var storiesRemainingForLevel2: Int = 0
    var totalLevel1Stories: Int = 0
    var completedLevel1Stories: Int = 0
    var showLevelUnlockAlert: Bool = false
    var showLockedLevelAlert: Bool = false
    var lockedLevelTapped: Int? = nil
    
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
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Listen for level unlock events
        dataService.levelUnlockedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                if level == 2 {
                    self?.showLevelUnlockAlert = true
                    self?.maxUnlockedLevel = 2
                }
            }
            .store(in: &cancellables)
        
        Task {
            await loadLevelProgress()
            // Default to showing current level
            selectedDifficulty = maxUnlockedLevel
            await loadStories()
        }
    }
    
    // MARK: - Story Progress Helpers
    
    func getStoryProgress(_ storyId: UUID) -> StoryProgress? {
        return storyProgress[storyId.uuidString]
    }
    
    func isStoryCompleted(_ storyId: UUID) -> Bool {
        return storyProgress[storyId.uuidString]?.isCompleted ?? false
    }
    
    func isStoryBookmarked(_ storyId: UUID) -> Bool {
        return storyProgress[storyId.uuidString]?.isBookmarked ?? false
    }
    
    func getReadingProgress(_ storyId: UUID) -> Double {
        return storyProgress[storyId.uuidString]?.readingProgress ?? 0.0
    }
    
    // MARK: - Data Loading
    
    func loadStories() async {
        isLoading = true
        defer { isLoading = false }
        
        let fetchedStories = await dataService.fetchStories(
            difficulty: selectedDifficulty,
            category: selectedCategory,
            searchQuery: searchQuery.isEmpty ? nil : searchQuery,
            sortBy: selectedSortOption
        )
        
        // Check for duplicates
        let storyIDs = fetchedStories.map { $0.id.uuidString }
        let uniqueIDs = Set(storyIDs)
        print("📚 LibraryViewModel: Loaded \(fetchedStories.count) stories, \(uniqueIDs.count) unique IDs")
        if storyIDs.count != uniqueIDs.count {
            print("⚠️ LibraryViewModel: DUPLICATE STORIES DETECTED!")
            // Find duplicates
            var seen: Set<String> = []
            for id in storyIDs {
                if seen.contains(id) {
                    print("   Duplicate ID: \(id)")
                } else {
                    seen.insert(id)
                }
            }
        }
        
        stories = fetchedStories
        filteredStories = stories
        
        // Fetch user-specific progress for all stories
        await loadStoryProgress()
    }
    
    func loadStoryProgress() async {
        // Fetch story progress for all displayed stories
        for story in stories {
            if let progress = await dataService.fetchStoryProgress(storyId: story.id) {
                storyProgress[story.id.uuidString] = progress
            }
        }
    }
    
    func loadLevelProgress() async {
        maxUnlockedLevel = await dataService.getMaxUnlockedLevel()
        
        // Calculate story-based progress for Level 2 unlock using user-specific story progress
        let allStories = await dataService.fetchAllStories()
        let level1Stories = allStories.filter { $0.difficultyLevel == 1 }
        
        // Fetch all story progress for the user
        let allProgress = await dataService.getAllStoryProgress()
        let completedStoryIds = Set(allProgress.filter { $0.isCompleted }.map { $0.storyId })
        
        totalLevel1Stories = level1Stories.count
        completedLevel1Stories = level1Stories.filter { story in
            completedStoryIds.contains(story.id.uuidString)
        }.count
        
        storiesRemainingForLevel2 = totalLevel1Stories - completedLevel1Stories
        storyProgressToLevel2 = totalLevel1Stories > 0 
            ? Double(completedLevel1Stories) / Double(totalLevel1Stories) 
            : 0
    }
    
    func refresh() async {
        await loadStories()
        await loadLevelProgress()
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
        await dataService.toggleStoryBookmark(storyId: story.id)
        // Update local cache
        if var progress = storyProgress[story.id.uuidString] {
            progress.toggleBookmark()
            storyProgress[story.id.uuidString] = progress
        } else {
            // Create new progress if doesn't exist
            let newProgress = await dataService.fetchStoryProgress(storyId: story.id)
            if let newProgress = newProgress {
                storyProgress[story.id.uuidString] = newProgress
            }
        }
    }
    
    func deleteStory(_ story: Story) async {
        do {
            try await dataService.deleteStory(story)
            await loadStories()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Level Management
    
    func canAccessLevel(_ level: Int) -> Bool {
        return level <= maxUnlockedLevel
    }
    
    func isLevelLocked(_ level: Int) -> Bool {
        return level > maxUnlockedLevel
    }
    
    // MARK: - Computed Properties
    
    var hasActiveFilters: Bool {
        selectedDifficulty != nil || selectedCategory != nil || !searchQuery.isEmpty
    }
    
    var storiesByDifficulty: [Int: [Story]] {
        Dictionary(grouping: stories) { $0.difficultyLevel }
    }
    
    var bookmarkedStories: [Story] {
        stories.filter { isStoryBookmarked($0.id) }
    }
    
    var inProgressStories: [Story] {
        stories.filter { 
            let progress = getReadingProgress($0.id)
            return progress > 0 && progress < 1.0 
        }.sorted { 
            let date1 = storyProgress[$0.id.uuidString]?.lastReadDate ?? .distantPast
            let date2 = storyProgress[$1.id.uuidString]?.lastReadDate ?? .distantPast
            return date1 > date2
        }
    }
    
    var continueReadingStory: Story? {
        inProgressStories.first
    }
    
    var completedStories: [Story] {
        stories.filter { isStoryCompleted($0.id) }
    }
    
    var difficultyCounts: [Int: Int] {
        Dictionary(grouping: stories) { $0.difficultyLevel }
            .mapValues { $0.count }
    }
    
    var level1Stories: [Story] {
        stories.filter { $0.difficultyLevel == 1 }
    }
    
    var level2PlusStories: [Story] {
        stories.filter { $0.difficultyLevel >= 2 }
    }
    
    var lockedLevelMessage: String {
        let remaining = storiesRemainingForLevel2
        if remaining == 1 {
            return "You're almost there! Complete 1 more story to unlock full Arabic reading."
        } else if remaining > 0 {
            return "Complete \(remaining) more stories to unlock full Arabic reading with Level 2."
        } else {
            return "Keep reading Level 1 stories to build your vocabulary first."
        }
    }
    
    var unlockProgressText: String {
        let remaining = storiesRemainingForLevel2
        if remaining == 1 {
            return "Read 1 more story to unlock Level 2"
        } else if remaining > 0 {
            return "Read \(remaining) more stories to unlock Level 2"
        } else {
            return "Complete all Level 1 stories to unlock Level 2"
        }
    }
    
    var hasUnlockedLevel2: Bool {
        maxUnlockedLevel >= 2
    }
    
    var storyProgressPercentage: Int {
        Int(storyProgressToLevel2 * 100)
    }
}
