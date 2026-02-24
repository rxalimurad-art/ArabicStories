//
//  DataService.swift
//  Arabicly
//  Data layer using Firebase Firestore
//

import Foundation
import Combine
import FirebaseAuth

enum NetworkError: LocalizedError {
    case noConnection
    case timeout
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection. Please check your network and try again."
        case .timeout:
            return "Request timed out. Please try again."
        case .serverError:
            return "Server error. Please try again later."
        }
    }
}

@Observable
class DataService {
    static let shared = DataService()

    private let firebaseService = FirebaseService.shared
    private let offlineDataService = OfflineDataService.shared
    private let networkMonitor = NetworkMonitor.shared

    // Publishers for reactive updates
    var storiesPublisher = CurrentValueSubject<[Story], Never>([])
    var isLoadingPublisher = CurrentValueSubject<Bool, Never>(false)
    var errorPublisher = PassthroughSubject<Error, Never>()
    var levelUnlockedPublisher = PassthroughSubject<Int, Never>()

    private init() {}
    
    private func checkNetwork() throws {
        guard networkMonitor.isConnected else {
            throw NetworkError.noConnection
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

    // MARK: - Story Operations (Offline)

    func fetchAllStories() async -> [Story] {
        isLoadingPublisher.send(true)
        defer { isLoadingPublisher.send(false) }

        print("📱 DataService: Loading stories from offline bundle...")
        
        // Load stories from offline bundle (no network required)
        let stories = offlineDataService.loadStories()
        print("📱 DataService: Loaded \(stories.count) stories from offline bundle")
        
        storiesPublisher.send(stories)
        return stories
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
        // Load from offline bundle instead of Firebase
        return offlineDataService.getStory(id: id)
    }

    func saveStory(_ story: Story) async throws {
        try await firebaseService.saveStory(story)
        _ = await fetchAllStories() // Refresh
    }

    func deleteStory(_ story: Story) async throws {
        try await firebaseService.deleteStory(id: story.id.uuidString)
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
    
    // MARK: - Quran Words Operations (Offline)
    
    func fetchAllQuranWords() -> [QuranWord] {
        return offlineDataService.loadQuranWords()
    }
    
    func fetchQuranWord(id: String) -> QuranWord? {
        return offlineDataService.getQuranWord(id: id)
    }
    
    func searchQuranWords(query: String) -> [QuranWord] {
        return offlineDataService.searchQuranWords(query: query)
    }
    
    func isWordInQuranWords(_ arabicText: String) -> Bool {
        return offlineDataService.isWordInQuranWords(arabicText)
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

    func recordVocabularyLearned(_ word: QuranWord) async {
        guard var progress = await fetchUserProgress() else { return }

        progress.recordVocabularyLearned(word)

        do {
            try await firebaseService.saveUserProgress(progress, userId: getCurrentUserId())
            
            // Also save to learnedQuranWords collection for MyWords view
            try await firebaseService.addLearnedQuranWord(word, userId: getCurrentUserId())
        } catch {
            errorPublisher.send(error)
        }
    }

    func recordVocabularyMastered(_ word: QuranWord) async {
        guard var progress = await fetchUserProgress() else { return }

        progress.recordVocabularyMastered(word)

        do {
            try await firebaseService.saveUserProgress(progress, userId: getCurrentUserId())
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

        do {
            if var progress = try await firebaseService.fetchUserProgress(userId: userId) {
                // Check and reset daily stats if new day started
                let didReset = progress.checkAndResetDailyStatsIfNeeded()
                
                if didReset {
                    // Save updated progress with reset stats
                    try await firebaseService.saveUserProgress(progress, userId: userId)
                }
                
                return progress
            }
        } catch {
            print("📱 DataService: Error fetching user progress: \(error)")
            return UserProgress()
        }

        return UserProgress()
    }

    func recordStudySession(minutes: Int) async {
        guard var progress = await fetchUserProgress() else { return }
        progress.recordStudySession(minutes: minutes)

        do {
            try await firebaseService.saveUserProgress(progress, userId: getCurrentUserId())
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
    }

    /// Record reading time for a story and update user's total reading time and daily goal
    func recordReadingTime(storyId: UUID, timeInterval: TimeInterval) async {
        guard var progress = await fetchUserProgress() else { return }

        // Update the user's total reading time
        progress.recordReadingTime(timeInterval)

        // Also update daily goal progress (convert seconds to minutes, rounding up)
        let minutes = Int(ceil(timeInterval / 60.0))
        if minutes > 0 {
            progress.recordStudySession(minutes: minutes)
            print("⏱️ Added \(minutes) minutes to daily goal")
        }

        do {
            try await firebaseService.saveUserProgress(progress, userId: getCurrentUserId())
            print("⏱️ Recorded \(Int(timeInterval))s reading time to user progress")
        } catch {
            print("❌ Error saving reading time to user progress: \(error)")
        }
    }

    // MARK: - Word Mastery (Firebase) - Updated for QuranWord

    func saveWordMastery(_ mastery: [String: WordMastery]) async {
        do {
            try await firebaseService.saveWordMastery(mastery, userId: getCurrentUserId())
            print("✅ Successfully saved \(mastery.count) word mastery entries to Firebase")
        } catch {
            print("❌ Error saving word mastery: \(error)")
            errorPublisher.send(error)
        }
    }

    func fetchWordMastery() async -> [String: WordMastery] {
        do {
            let result = try await firebaseService.fetchWordMastery(userId: getCurrentUserId())
            print("✅ Successfully loaded \(result.count) word mastery entries from Firebase")
            return result
        } catch {
            print("❌ Error loading word mastery: \(error)")
            return [:]
        }
    }
    
    // MARK: - Learned Quran Words (New)
    
    func saveLearnedQuranWords(_ words: [QuranWord]) async {
        do {
            try await firebaseService.saveLearnedQuranWords(words, userId: getCurrentUserId())
            print("✅ Successfully saved \(words.count) learned Quran words")
        } catch {
            print("❌ Error saving learned Quran words: \(error)")
            errorPublisher.send(error)
        }
    }
    
    func fetchLearnedQuranWords() async -> [QuranWord] {
        do {
            let result = try await firebaseService.fetchLearnedQuranWords(userId: getCurrentUserId())
            print("✅ Successfully loaded \(result.count) learned Quran words")
            return result
        } catch {
            print("❌ Error loading learned Quran words: \(error)")
            return []
        }
    }
    
    func updateQuranWordBookmark(wordId: String, isBookmarked: Bool) async {
        do {
            try await firebaseService.updateLearnedQuranWordField(
                wordId: wordId,
                userId: getCurrentUserId(),
                field: "isBookmarked",
                value: isBookmarked
            )
        } catch {
            print("❌ Error updating Quran word bookmark: \(error)")
        }
    }
    
    func isQuranWordLearned(_ wordId: String) async -> Bool {
        do {
            return try await firebaseService.isQuranWordLearned(wordId, userId: getCurrentUserId())
        } catch {
            print("❌ Error checking if Quran word is learned: \(error)")
            return false
        }
    }
    
    // MARK: - Unlocked Words (New Optimized)
    
    func saveUnlockedWords(_ words: [UnlockedWord]) async {
        do {
            try await firebaseService.saveUnlockedWords(words, userId: getCurrentUserId())
        } catch {
            print("❌ Error saving unlocked words: \(error)")
        }
    }
    
    func fetchUnlockedWords() async -> [UnlockedWord] {
        do {
            return try await firebaseService.fetchUnlockedWords(userId: getCurrentUserId())
        } catch {
            print("❌ Error fetching unlocked words: \(error)")
            return []
        }
    }
    
    func addUnlockedWord(_ word: UnlockedWord) async {
        do {
            try await firebaseService.addUnlockedWord(word, userId: getCurrentUserId())
        } catch {
            print("❌ Error adding unlocked word: \(error)")
        }
    }
    
    func isWordUnlocked(_ wordId: UUID) async -> Bool {
        do {
            return try await firebaseService.isWordUnlocked(wordId, userId: getCurrentUserId())
        } catch {
            print("❌ Error checking word unlock status: \(error)")
            return false
        }
    }

    func updateWordBookmark(wordId: UUID, isBookmarked: Bool) async {
        do {
            try await firebaseService.updateUnlockedWordField(
                wordId: wordId,
                userId: getCurrentUserId(),
                field: "wordData.isBookmarked",
                value: isBookmarked
            )
        } catch {
            print("❌ Error updating word bookmark: \(error)")
        }
    }

    // MARK: - Story Progress (User-Specific)

    func fetchStoryProgress(storyId: UUID) async -> StoryProgress? {
        let userId = getCurrentUserId()

        do {
            if let progress = try await firebaseService.fetchStoryProgress(
                storyId: storyId.uuidString,
                userId: userId
            ) {
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

        // Save to Firebase
        do {
            print("💾 Saving story progress: storyId=\(storyProgress.storyId), userId=\(storyProgress.userId), progress=\(storyProgress.readingProgress), isCompleted=\(storyProgress.isCompleted)")
            try await firebaseService.saveStoryProgress(storyProgress)
            print("✅ Story progress saved successfully")

            // If story is completed, update user progress
            if storyProgress.isCompleted {
                print("🎉 Story completed! Updating user progress...")
                if let story = await fetchStory(id: storyId) {
                    let unlocked = await recordStoryCompleted(
                        storyId: storyId.uuidString,
                        difficultyLevel: story.difficultyLevel
                    )
                    print("🎉 Level 2 unlocked: \(unlocked)")
                }
            }
        } catch {
            print("❌ Error saving story progress: \(error)")
            errorPublisher.send(error)
        }
    }

    func toggleStoryBookmark(storyId: UUID) async {
        var storyProgress = await fetchStoryProgress(storyId: storyId)
            ?? StoryProgress(storyId: storyId.uuidString, userId: getCurrentUserId())

        storyProgress.toggleBookmark()

        do {
            try await firebaseService.saveStoryProgress(storyProgress)
        } catch {
            errorPublisher.send(error)
        }
    }

    func markStoryWordAsLearned(storyId: UUID, wordId: String) async {
        var storyProgress = await fetchStoryProgress(storyId: storyId)
            ?? StoryProgress(storyId: storyId.uuidString, userId: getCurrentUserId())

        storyProgress.markWordAsLearned(wordId)

        // Also update global vocabulary progress if we can fetch the word from offline bundle
        if let quranWord = offlineDataService.getQuranWord(id: wordId) {
            await recordVocabularyLearned(quranWord)
        }

        do {
            try await firebaseService.saveStoryProgress(storyProgress)
        } catch {
            errorPublisher.send(error)
        }
    }

    func getAllStoryProgress() async -> [StoryProgress] {
        let userId = getCurrentUserId()
        do {
            return try await firebaseService.fetchAllStoryProgressForUser(userId: userId)
        } catch {
            print("❌ Error fetching all story progress: \(error)")
            return []
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
