//
//  OfflineDataService.swift
//  Arabicly
//  Service for loading offline JSON data from app bundle
//

import Foundation

@Observable
class OfflineDataService {
    static let shared = OfflineDataService()
    
    private let storiesFilename = "stories"
    private let quranWordsFilename = "quran_words"
    
    private var cachedStories: [Story]?
    private var cachedQuranWords: [QuranWord]?
    private var quranWordIdIndex: [String: QuranWord]?
    private var quranWordArabicIndex: [String: QuranWord]?
    
    private init() {}
    
    // MARK: - Stories
    
    /// Load all stories from the offline JSON bundle
    func loadStories() -> [Story] {
        // Return cached stories if available
        if let cached = cachedStories {
            print("📱 OfflineDataService: Returning \(cached.count) cached stories")
            return cached
        }
        
        // Try multiple approaches to find the file
        let url = findFileInBundle(named: storiesFilename, extension: "json")
        
        guard let fileURL = url else {
            print("❌ OfflineDataService: Could not find \(storiesFilename).json in bundle")
            print("📂 Bundle path: \(Bundle.main.bundlePath)")
            
            // List all files in bundle for debugging
            if let enumerator = FileManager.default.enumerator(atPath: Bundle.main.bundlePath) {
                print("📂 Bundle contents:")
                for case let filePath as String in enumerator {
                    if filePath.hasSuffix(".json") {
                        print("   - \(filePath)")
                    }
                }
            }
            return []
        }
        
        print("📱 OfflineDataService: Found stories.json at: \(fileURL.path)")
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let bundle = try decoder.decode(StoriesBundle.self, from: data)
            cachedStories = bundle.stories
            print("✅ OfflineDataService: Loaded \(bundle.stories.count) stories from bundle (version: \(bundle.version))")
            return bundle.stories
        } catch {
            print("❌ OfflineDataService: Failed to decode stories: \(error)")
            return []
        }
    }
    
    /// Helper to find a file in the bundle (handles different folder structures)
    private func findFileInBundle(named name: String, extension ext: String) -> URL? {
        // Try 1: Direct path with subdirectory
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "OfflineBundle") {
            return url
        }
        
        // Try 2: Without subdirectory
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return url
        }
        
        // Try 3: Search recursively in bundle
        if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
            for url in urls {
                if url.lastPathComponent == "\(name).\(ext)" {
                    return url
                }
            }
        }
        
        // Try 4: Manual path construction (for local development)
        let manualPath = Bundle.main.bundlePath + "/OfflineBundle/\(name).\(ext)"
        let manualURL = URL(fileURLWithPath: manualPath)
        if FileManager.default.fileExists(atPath: manualURL.path) {
            return manualURL
        }
        
        return nil
    }
    
    /// Get a specific story by ID
    func getStory(id: UUID) -> Story? {
        let stories = loadStories()
        return stories.first { $0.id == id }
    }
    
    /// Get stories by difficulty level
    func getStoriesByDifficulty(level: Int) -> [Story] {
        let stories = loadStories()
        return stories.filter { $0.difficultyLevel == level }
    }
    
    /// Search stories by title or author
    func searchStories(query: String) -> [Story] {
        let stories = loadStories()
        let lowerQuery = query.lowercased()
        return stories.filter {
            $0.title.localizedStandardContains(lowerQuery) ||
            $0.author.localizedStandardContains(lowerQuery) ||
            ($0.titleArabic?.contains(query) ?? false)
        }
    }
    
    /// Clear stories cache (useful if you want to reload)
    func clearStoriesCache() {
        cachedStories = nil
        print("📱 OfflineDataService: Cleared stories cache")
    }
    
    // MARK: - Quran Words
    
    /// Load all Quran words from the offline JSON bundle
    func loadQuranWords() -> [QuranWord] {
        // Return cached words if available
        if let cached = cachedQuranWords {
            print("📱 OfflineDataService: Returning \(cached.count) cached Quran words")
            return cached
        }
        
        // Try multiple approaches to find the file
        let url = findFileInBundle(named: quranWordsFilename, extension: "json")
        
        guard let fileURL = url else {
            print("❌ OfflineDataService: Could not find \(quranWordsFilename).json in bundle")
            return []
        }
        
        print("📱 OfflineDataService: Found quran_words.json at: \(fileURL.path)")
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let bundle = try decoder.decode(QuranWordsBundle.self, from: data)
            cachedQuranWords = bundle.words
            // Build O(1) lookup indexes (keep first occurrence on duplicate keys)
            quranWordIdIndex = Dictionary(bundle.words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            quranWordArabicIndex = Dictionary(bundle.words.map { ($0.arabicWithoutDiacritics, $0) }, uniquingKeysWith: { first, _ in first })
            print("✅ OfflineDataService: Loaded \(bundle.words.count) Quran words from bundle (version: \(bundle.version))")
            return bundle.words
        } catch {
            print("❌ OfflineDataService: Failed to decode Quran words: \(error)")
            return []
        }
    }
    
    /// Get a specific Quran word by ID
    func getQuranWord(id: String) -> QuranWord? {
        if let index = quranWordIdIndex {
            return index[id]
        }
        let words = loadQuranWords()
        return words.first { $0.id == id }
    }
    
    /// Search Quran words by Arabic text or English meaning
    func searchQuranWords(query: String) -> [QuranWord] {
        let words = loadQuranWords()
        
        // Check if query contains Arabic characters
        let containsArabic = query.range(of: "[\\u0600-\\u06FF]", options: .regularExpression) != nil
        
        if containsArabic {
            return words.filter { word in
                word.arabicText.contains(query) ||
                word.arabicWithoutDiacritics.contains(query)
            }
        } else {
            let lowerQuery = query.lowercased()
            return words.filter { word in
                word.englishMeaning.lowercased().contains(lowerQuery)
            }
        }
    }
    
    /// Get words filtered by part of speech
    func getQuranWordsByPOS(_ pos: String) -> [QuranWord] {
        let words = loadQuranWords()
        return words.filter { $0.morphology.partOfSpeech == pos }
    }
    
    /// Get words filtered by root
    func getQuranWordsByRoot(root: String) -> [QuranWord] {
        let words = loadQuranWords()
        return words.filter { $0.root?.arabic == root }
    }
    
    /// Get words with pagination
    func getQuranWordsPaginated(page: Int, pageSize: Int) -> [QuranWord] {
        let words = loadQuranWords()
        let startIndex = (page - 1) * pageSize
        let endIndex = min(startIndex + pageSize, words.count)
        
        guard startIndex < words.count else { return [] }
        return Array(words[startIndex..<endIndex])
    }
    
    /// Get total count of Quran words
    func getQuranWordsCount() -> Int {
        return loadQuranWords().count
    }
    
    /// Clear Quran words cache
    func clearQuranWordsCache() {
        cachedQuranWords = nil
        quranWordIdIndex = nil
        quranWordArabicIndex = nil
        print("📱 OfflineDataService: Cleared Quran words cache")
    }
    
    /// Check if a word exists in the Quran words collection (for highlighting)
    func isWordInQuranWords(_ arabicText: String) -> Bool {
        if let index = quranWordArabicIndex {
            let normalized = ArabicTextUtils.stripDiacritics(arabicText)
            return index[normalized] != nil
        }
        let words = loadQuranWords()
        return words.contains { word in
            ArabicTextUtils.wordsMatch(word.arabicWithoutDiacritics, arabicText)
        }
    }

    /// Find a Quran word by its Arabic text
    func findQuranWordByArabic(_ arabicText: String) -> QuranWord? {
        if let index = quranWordArabicIndex {
            let normalized = ArabicTextUtils.stripDiacritics(arabicText)
            return index[normalized]
        }
        let words = loadQuranWords()
        return words.first { word in
            ArabicTextUtils.wordsMatch(word.arabicWithoutDiacritics, arabicText)
        }
    }
    
    // MARK: - Stats
    
    /// Get Quran statistics
    func getQuranStats() -> QuranStats {
        let words = loadQuranWords()
        let uniqueRoots = Set(words.compactMap { $0.root?.arabic })
        
        return QuranStats(
            totalUniqueWords: words.count,
            totalTokens: words.reduce(0) { $0 + $1.occurrenceCount },
            uniqueRoots: uniqueRoots.count,
            uniqueRootForms: uniqueRoots.count,
            wordsWithRoots: words.filter { $0.root != nil }.count,
            wordsWithPOS: words.filter { $0.morphology.partOfSpeech != nil }.count,
            wordsWithLemmas: words.filter { $0.morphology.lemma != nil }.count,
            wordsWithMeanings: words.filter { !$0.englishMeaning.isEmpty }.count,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            version: "1.0"
        )
    }
    
    /// Get all unique roots from Quran words
    func getUniqueRoots() -> [String] {
        let words = loadQuranWords()
        let roots = Set(words.compactMap { $0.root?.arabic })
        return Array(roots).sorted()
    }
}

// MARK: - Bundle Models

struct StoriesBundle: Codable {
    let version: String
    let lastUpdated: String
    let stories: [Story]
}

struct QuranWordsBundle: Codable {
    let version: String
    let lastUpdated: String
    let totalWords: Int
    let words: [QuranWord]
}
