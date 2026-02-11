//
//  DataService.swift
//  Hikaya
//  Data layer using Firebase Firestore
//

import Foundation
import Combine

@Observable
class DataService {
    static let shared = DataService()
    
    private let firebaseService = FirebaseService.shared
    private let localCache = LocalCache.shared
    
    // User ID for data separation (could be from Firebase Auth)
    private var userId: String = "default_user"
    
    // Publishers for reactive updates
    var storiesPublisher = CurrentValueSubject<[Story], Never>([])
    var isLoadingPublisher = CurrentValueSubject<Bool, Never>(false)
    var errorPublisher = PassthroughSubject<Error, Never>()
    var levelUnlockedPublisher = PassthroughSubject<Int, Never>()
    
    private init() {}
    
    // MARK: - Level Management
    
    func getMaxUnlockedLevel() async -> Int {
        let progress = await fetchUserProgress()
        return progress?.maxUnlockedLevel ?? 1
    }
    
    func canAccessLevel(_ level: Int) async -> Bool {
        let maxLevel = await getMaxUnlockedLevel()
        return level <= maxLevel
    }
    
    func vocabularyProgressToLevel2() async -> Double {
        let progress = await fetchUserProgress()
        return progress?.vocabularyProgressToLevel2 ?? 0.0
    }
    
    func vocabularyRemainingForLevel2() async -> Int {
        let progress = await fetchUserProgress()
        return progress?.vocabularyRemainingForLevel2 ?? 20
    }
    
    // MARK: - Story Operations
    
    func fetchAllStories() async -> [Story] {
        isLoadingPublisher.send(true)
        defer { isLoadingPublisher.send(false) }
        
        print("📱 DataService: Fetching all stories...")
        
        do {
            // Try to fetch from Firebase first
            print("📱 DataService: Calling firebaseService.fetchStories()")
            let stories = try await firebaseService.fetchStories()
            print("📱 DataService: Got \(stories.count) stories from Firebase")
            
            // Cache locally
            await localCache.saveStories(stories)
            
            storiesPublisher.send(stories)
            return stories
        } catch {
            print("📱 DataService: Error fetching from Firebase: \(error)")
            // Fallback to cache
            errorPublisher.send(error)
            let cachedStories = await localCache.fetchStories()
            print("📱 DataService: Returning \(cachedStories.count) cached stories")
            return cachedStories
        }
    }
    
    func fetchStories(
        difficulty: Int? = nil,
        category: StoryCategory? = nil,
        searchQuery: String? = nil,
        sortBy: SortOption = .newest,
        isBookmarked: Bool? = nil
    ) async -> [Story] {
        var stories = await fetchAllStories()
        
        // Filter by level access
        let maxLevel = await getMaxUnlockedLevel()
        stories = stories.filter { $0.difficultyLevel <= maxLevel }
        
        // Filter
        if let difficulty = difficulty {
            stories = stories.filter { $0.difficultyLevel == difficulty }
        }
        
        if let category = category {
            stories = stories.filter { $0.category == category }
        }
        
        if let isBookmarked = isBookmarked {
            stories = stories.filter { $0.isBookmarked == isBookmarked }
        }
        
        if let query = searchQuery, !query.isEmpty {
            let lowerQuery = query.lowercased()
            stories = stories.filter {
                $0.title.localizedStandardContains(lowerQuery) ||
                $0.author.localizedStandardContains(lowerQuery)
            }
        }
        
        // Sort
        switch sortBy {
        case .newest:
            stories.sort { $0.createdAt > $1.createdAt }
        case .easiest:
            stories.sort { $0.difficultyLevel < $1.difficultyLevel }
        case .mostPopular:
            stories.sort { $0.viewCount > $1.viewCount }
        case .recentlyRead:
            stories.sort { ($0.lastReadDate ?? .distantPast) > ($1.lastReadDate ?? .distantPast) }
        case .alphabetical:
            stories.sort { $0.title < $1.title }
        }
        
        return stories
    }
    
    func fetchStoriesByFormat(_ format: StoryFormat) async -> [Story] {
        let stories = await fetchAllStories()
        return stories.filter { $0.format == format }
    }
    
    func fetchStory(id: UUID) async -> Story? {
        // Check cache first
        if let cached = await localCache.fetchStory(id: id) {
            return cached
        }
        
        // Fetch from Firebase
        do {
            if let story = try await firebaseService.fetchStory(id: id.uuidString) {
                await localCache.saveStory(story)
                return story
            }
        } catch {
            errorPublisher.send(error)
        }
        
        return nil
    }
    
    func saveStory(_ story: Story) async throws {
        try await firebaseService.saveStory(story)
        await localCache.saveStory(story)
        _ = await fetchAllStories() // Refresh
    }
    
    func deleteStory(_ story: Story) async throws {
        try await firebaseService.deleteStory(id: story.id.uuidString)
        await localCache.deleteStory(id: story.id)
        _ = await fetchAllStories() // Refresh
    }
    
    func toggleBookmark(_ story: Story) async {
        var updatedStory = story
        updatedStory.isBookmarked.toggle()
        updatedStory.updatedAt = Date()
        
        do {
            try await saveStory(updatedStory)
        } catch {
            errorPublisher.send(error)
        }
    }
    
    // MARK: - Word Operations
    
    func fetchAllWords() async -> [Word] {
        let stories = await fetchAllStories()
        return stories.compactMap { $0.words }.flatMap { $0 }
    }
    
    func fetchBookmarkedWords() async -> [Word] {
        let words = await fetchAllWords()
        return words.filter { $0.isBookmarked ?? false }
    }
    
    func toggleWordBookmark(_ word: Word) async {
        // Words are saved as part of stories, so we'd need to update the parent story
        // This is a simplified implementation
    }
    
    // MARK: - Vocabulary Learning
    
    func recordVocabularyLearned(wordId: String) async -> Bool {
        guard var progress = await fetchUserProgress() else { return false }
        
        let unlockedLevel = progress.recordVocabularyLearned(wordId: wordId)
        
        do {
            try await firebaseService.saveUserProgress(progress, userId: userId)
            await localCache.saveUserProgress(progress)
            
            // Publish level unlock event if Level 2 was unlocked
            if unlockedLevel {
                levelUnlockedPublisher.send(2)
            }
            
            return unlockedLevel
        } catch {
            errorPublisher.send(error)
            return false
        }
    }
    
    func recordVocabularyMastered(wordId: String) async {
        guard var progress = await fetchUserProgress() else { return }
        
        progress.recordVocabularyMastered(wordId: wordId)
        
        do {
            try await firebaseService.saveUserProgress(progress, userId: userId)
            await localCache.saveUserProgress(progress)
        } catch {
            errorPublisher.send(error)
        }
    }
    
    func getLearnedVocabularyIds() async -> [String] {
        let progress = await fetchUserProgress()
        return progress?.learnedVocabularyIds ?? []
    }
    
    func getMasteredVocabularyIds() async -> [String] {
        let progress = await fetchUserProgress()
        return progress?.masteredVocabularyIds ?? []
    }
    
    // MARK: - Story Progress with Vocabulary
    
    func markStoryWordAsLearned(storyId: UUID, wordId: String) async {
        // Update story progress
        if var story = await fetchStory(id: storyId) {
            story.markWordAsLearned(wordId)
            try? await saveStory(story)
        }
        
        // Update global vocabulary progress
        await recordVocabularyLearned(wordId: wordId)
    }
    
    // MARK: - User Progress Operations
    
    func fetchUserProgress() async -> UserProgress? {
        // Check cache first
        if let cached = await localCache.fetchUserProgress() {
            return cached
        }
        
        // Fetch from Firebase
        do {
            if let progress = try await firebaseService.fetchUserProgress(userId: userId) {
                await localCache.saveUserProgress(progress)
                return progress
            }
        } catch {
            // Return default if not found
            return UserProgress()
        }
        
        return UserProgress()
    }
    
    func recordStudySession(minutes: Int) async {
        guard var progress = await fetchUserProgress() else { return }
        progress.recordStudySession(minutes: minutes)
        
        do {
            try await firebaseService.saveUserProgress(progress, userId: userId)
            await localCache.saveUserProgress(progress)
        } catch {
            errorPublisher.send(error)
        }
    }
    
    func recordStoryCompleted(difficultyLevel: Int) async {
        guard var progress = await fetchUserProgress() else { return }
        progress.recordStoryCompleted(difficultyLevel: difficultyLevel)
        
        do {
            try await firebaseService.saveUserProgress(progress, userId: userId)
            await localCache.saveUserProgress(progress)
        } catch {
            errorPublisher.send(error)
        }
    }
    
    func updateUserProgress(_ progress: UserProgress) async throws {
        try await firebaseService.saveUserProgress(progress, userId: userId)
        await localCache.saveUserProgress(progress)
    }
}

// MARK: - Local Cache (In-Memory + UserDefaults)

@Observable
class LocalCache {
    static let shared = LocalCache()
    
    private var stories: [Story] = []
    private var userProgress: UserProgress?
    private let defaults = UserDefaults.standard
    
    private init() {
        // Load from UserDefaults on init
        loadFromDisk()
    }
    
    // MARK: - Stories
    
    func fetchStories() async -> [Story] {
        return stories
    }
    
    func fetchStory(id: UUID) async -> Story? {
        return stories.first { $0.id == id }
    }
    
    func saveStories(_ stories: [Story]) async {
        self.stories = stories
        saveToDisk()
    }
    
    func saveStory(_ story: Story) async {
        if let index = stories.firstIndex(where: { $0.id == story.id }) {
            stories[index] = story
        } else {
            stories.append(story)
        }
        saveToDisk()
    }
    
    func deleteStory(id: UUID) async {
        stories.removeAll { $0.id == id }
        saveToDisk()
    }
    
    // MARK: - User Progress
    
    func fetchUserProgress() async -> UserProgress? {
        return userProgress
    }
    
    func saveUserProgress(_ progress: UserProgress) async {
        self.userProgress = progress
        saveToDisk()
    }
    
    // MARK: - Persistence
    
    private func saveToDisk() {
        if let storiesData = try? JSONEncoder().encode(stories) {
            defaults.set(storiesData, forKey: "cached_stories")
        }
        if let progressData = try? JSONEncoder().encode(userProgress) {
            defaults.set(progressData, forKey: "cached_progress")
        }
    }
    
    private func loadFromDisk() {
        if let storiesData = defaults.data(forKey: "cached_stories"),
           let decodedStories = try? JSONDecoder().decode([Story].self, from: storiesData) {
            self.stories = decodedStories
        }
        if let progressData = defaults.data(forKey: "cached_progress"),
           let decodedProgress = try? JSONDecoder().decode(UserProgress.self, from: progressData) {
            self.userProgress = decodedProgress
        }
    }
}

// MARK: - Sort Options

enum SortOption: String, CaseIterable, Identifiable {
    case newest = "newest"
    case easiest = "easiest"
    case mostPopular = "most_popular"
    case recentlyRead = "recently_read"
    case alphabetical = "alphabetical"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .newest: return "Newest"
        case .easiest: return "Easiest"
        case .mostPopular: return "Most Popular"
        case .recentlyRead: return "Recently Read"
        case .alphabetical: return "A-Z"
        }
    }
    
    var icon: String {
        switch self {
        case .newest: return "calendar"
        case .easiest: return "chart.bar"
        case .mostPopular: return "flame"
        case .recentlyRead: return "clock"
        case .alphabetical: return "textformat.abc"
        }
    }
}
