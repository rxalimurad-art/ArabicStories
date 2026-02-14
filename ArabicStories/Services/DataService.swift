//
//  DataService.swift
//  Arabicly
//  Data layer using Firebase Firestore
//

import Foundation
import Combine
import FirebaseAuth

@Observable
class DataService {
    static let shared = DataService()
    
    private let firebaseService = FirebaseService.shared
    private let localCache = LocalCache.shared
    
    // Publishers for reactive updates
    var storiesPublisher = CurrentValueSubject<[Story], Never>([])
    var isLoadingPublisher = CurrentValueSubject<Bool, Never>(false)
    var errorPublisher = PassthroughSubject<Error, Never>()
    var levelUnlockedPublisher = PassthroughSubject<Int, Never>()
    
    private init() {
        // Observe auth state changes to update userId
        setupAuthObserver()
    }
    
    private func setupAuthObserver() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            let userId = user?.uid ?? "anonymous"
            Task {
                await self.localCache.switchUser(userId)
            }
        }
    }
    
    // Get current Firebase Auth user ID
    private func getCurrentUserId() -> String {
        if let user = Auth.auth().currentUser {
            return user.uid
        }
        return "anonymous"
    }
    
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
    
    func recordVocabularyLearned(wordId: String) async {
        guard var progress = await fetchUserProgress() else { return }
        
        progress.recordVocabularyLearned(wordId: wordId)
        
        do {
            try await firebaseService.saveUserProgress(progress, userId: getCurrentUserId())
            await localCache.saveUserProgress(progress)
            
            // Note: Level 2 is now unlocked by completing all Level 1 stories, not vocabulary
        } catch {
            errorPublisher.send(error)
        }
    }
    
    func recordVocabularyMastered(wordId: String) async {
        guard var progress = await fetchUserProgress() else { return }
        
        progress.recordVocabularyMastered(wordId: wordId)
        
        do {
            try await firebaseService.saveUserProgress(progress, userId: getCurrentUserId())
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
    
    // MARK: - User Progress Operations
    
    func fetchUserProgress() async -> UserProgress? {
        let userId = getCurrentUserId()
        
        // Check cache first (user-specific)
        if let cached = await localCache.fetchUserProgress() {
            // Verify cache belongs to current user by checking if we're authenticated
            // If user is logged in, always fetch from Firebase to ensure fresh data
            if Auth.auth().currentUser == nil {
                return cached
            }
        }
        
        // Fetch from Firebase (always fetch for authenticated users to ensure isolation)
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
            try await firebaseService.saveUserProgress(progress, userId: getCurrentUserId())
            await localCache.saveUserProgress(progress)
        } catch {
            errorPublisher.send(error)
        }
    }
    
    func recordStoryCompleted(storyId: String, difficultyLevel: Int) async -> Bool {
        guard var progress = await fetchUserProgress() else { return false }
        
        // Get total Level 1 stories count for unlock check
        let allStories = await fetchAllStories()
        let totalLevel1Stories = allStories.filter { $0.difficultyLevel == 1 }.count
        
        let unlocked = progress.recordStoryCompleted(
            storyId: storyId,
            difficultyLevel: difficultyLevel,
            totalStoriesInLevel1: totalLevel1Stories
        )
        
        do {
            try await firebaseService.saveUserProgress(progress, userId: getCurrentUserId())
            await localCache.saveUserProgress(progress)
            
            // Publish level unlock event if Level 2 was unlocked
            if unlocked {
                levelUnlockedPublisher.send(2)
            }
            
            return unlocked
        } catch {
            errorPublisher.send(error)
            return false
        }
    }
    
    func updateUserProgress(_ progress: UserProgress) async throws {
        try await firebaseService.saveUserProgress(progress, userId: getCurrentUserId())
        await localCache.saveUserProgress(progress)
    }
    
    /// Record reading time for a story and update user's total reading time
    func recordReadingTime(storyId: UUID, timeInterval: TimeInterval) async {
        guard var progress = await fetchUserProgress() else { return }
        
        // Update the user's total reading time
        progress.recordReadingTime(timeInterval)
        
        do {
            try await firebaseService.saveUserProgress(progress, userId: getCurrentUserId())
            await localCache.saveUserProgress(progress)
            print("⏱️ Recorded \(Int(timeInterval))s reading time to user progress")
        } catch {
            print("❌ Error saving reading time to user progress: \(error)")
        }
    }
    
    // MARK: - Story Progress (User-Specific)
    
    func fetchStoryProgress(storyId: UUID) async -> StoryProgress? {
        let userId = getCurrentUserId()
        
        // Check cache first
        if let cached = await localCache.fetchStoryProgress(storyId: storyId) {
            return cached
        }
        
        // Fetch from Firebase
        do {
            if let progress = try await firebaseService.fetchStoryProgress(
                storyId: storyId.uuidString,
                userId: userId
            ) {
                await localCache.saveStoryProgress(progress)
                return progress
            }
        } catch {
            print("❌ Error fetching story progress: \(error)")
        }
        
        // Return new progress if not found
        return StoryProgress(storyId: storyId.uuidString, userId: userId)
    }
    
    func updateStoryProgress(
        storyId: UUID,
        readingProgress: Double? = nil,
        currentSegmentIndex: Int? = nil,
        readingTime: TimeInterval? = nil
    ) async {
        var storyProgress = await fetchStoryProgress(storyId: storyId) 
            ?? StoryProgress(storyId: storyId.uuidString, userId: getCurrentUserId())
        
        // Update fields
        if let progress = readingProgress {
            storyProgress.updateProgress(progress)
        }
        if let segmentIndex = currentSegmentIndex {
            storyProgress.updateSegmentIndex(segmentIndex)
        }
        if let time = readingTime {
            storyProgress.addReadingTime(time)
        }
        
        // Save to Firebase and cache
        do {
            try await firebaseService.saveStoryProgress(storyProgress)
            await localCache.saveStoryProgress(storyProgress)
            
            // If story is completed, update user progress
            if storyProgress.isCompleted {
                if let story = await fetchStory(id: storyId) {
                    _ = await recordStoryCompleted(
                        storyId: storyId.uuidString,
                        difficultyLevel: story.difficultyLevel
                    )
                }
            }
        } catch {
            errorPublisher.send(error)
        }
    }
    
    func toggleStoryBookmark(storyId: UUID) async {
        var storyProgress = await fetchStoryProgress(storyId: storyId) 
            ?? StoryProgress(storyId: storyId.uuidString, userId: getCurrentUserId())
        
        storyProgress.toggleBookmark()
        
        do {
            try await firebaseService.saveStoryProgress(storyProgress)
            await localCache.saveStoryProgress(storyProgress)
        } catch {
            errorPublisher.send(error)
        }
    }
    
    func markStoryWordAsLearned(storyId: UUID, wordId: String) async {
        var storyProgress = await fetchStoryProgress(storyId: storyId) 
            ?? StoryProgress(storyId: storyId.uuidString, userId: getCurrentUserId())
        
        storyProgress.markWordAsLearned(wordId)
        
        // Also update global vocabulary progress
        await recordVocabularyLearned(wordId: wordId)
        
        do {
            try await firebaseService.saveStoryProgress(storyProgress)
            await localCache.saveStoryProgress(storyProgress)
        } catch {
            errorPublisher.send(error)
        }
    }
    
    func getAllStoryProgress() async -> [StoryProgress] {
        return await localCache.fetchAllStoryProgress()
    }
}

// MARK: - Local Cache (In-Memory + UserDefaults)

@Observable
class LocalCache {
    static let shared = LocalCache()
    
    private var stories: [Story] = []
    private var userProgress: UserProgress?
    private var storyProgress: [String: StoryProgress] = [:] // Key: "storyId"
    private var currentUserId: String = "anonymous"
    private let defaults = UserDefaults.standard
    
    private init() {
        // Load from UserDefaults on init
        loadFromDisk()
    }
    
    // Switch to a different user's cache
    func switchUser(_ userId: String) async {
        // Save current user's cache first
        saveToDisk()
        
        // Switch to new user
        currentUserId = userId
        
        // Clear in-memory cache
        userProgress = nil
        storyProgress = [:]
        
        // Load new user's cache
        loadFromDisk()
        
        print("📱 LocalCache: Switched to user \(userId)")
    }
    
    // MARK: - Stories (shared across users)
    
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
    
    // MARK: - User Progress (user-specific)
    
    func fetchUserProgress() async -> UserProgress? {
        return userProgress
    }
    
    func saveUserProgress(_ progress: UserProgress) async {
        self.userProgress = progress
        saveToDisk()
    }
    
    // MARK: - Story Progress (user-specific)
    
    func fetchStoryProgress(storyId: UUID) async -> StoryProgress? {
        return storyProgress[storyId.uuidString]
    }
    
    func saveStoryProgress(_ progress: StoryProgress) async {
        storyProgress[progress.storyId] = progress
        saveToDisk()
    }
    
    func fetchAllStoryProgress() async -> [StoryProgress] {
        return Array(storyProgress.values)
    }
    
    // MARK: - Persistence
    
    private func saveToDisk() {
        // Stories are shared (same for all users)
        if let storiesData = try? JSONEncoder().encode(stories) {
            defaults.set(storiesData, forKey: "cached_stories")
        }
        
        // Progress is user-specific
        if let progressData = try? JSONEncoder().encode(userProgress) {
            defaults.set(progressData, forKey: "cached_progress_\(currentUserId)")
        }
        
        // Story progress is user-specific
        if let storyProgressData = try? JSONEncoder().encode(storyProgress) {
            defaults.set(storyProgressData, forKey: "cached_story_progress_\(currentUserId)")
        }
    }
    
    private func loadFromDisk() {
        // Load stories (shared)
        if let storiesData = defaults.data(forKey: "cached_stories"),
           let decodedStories = try? JSONDecoder().decode([Story].self, from: storiesData) {
            self.stories = decodedStories
        }
        
        // Load user-specific progress
        if let progressData = defaults.data(forKey: "cached_progress_\(currentUserId)"),
           let decodedProgress = try? JSONDecoder().decode(UserProgress.self, from: progressData) {
            self.userProgress = decodedProgress
        } else {
            self.userProgress = nil
        }
        
        // Load user-specific story progress
        if let storyProgressData = defaults.data(forKey: "cached_story_progress_\(currentUserId)"),
           let decodedStoryProgress = try? JSONDecoder().decode([String: StoryProgress].self, from: storyProgressData) {
            self.storyProgress = decodedStoryProgress
        } else {
            self.storyProgress = [:]
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
