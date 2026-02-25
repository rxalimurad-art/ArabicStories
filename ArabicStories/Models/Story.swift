//
//  Story.swift
//  Arabicly
//  Story model - Firebase compatible (no SwiftData)
//

import Foundation

// MARK: - Story Format Type
enum StoryFormat: String, Codable, CaseIterable {
    case mixed = "mixed"           // Level 1: English with Arabic words
    case bilingual = "bilingual"   // Level 2+: Full Arabic with English translation
}

struct Story: Identifiable, Codable, Hashable {
    // MARK: - Identification
    var id: UUID
    var title: String
    var titleArabic: String?
    var storyDescription: String
    var storyDescriptionArabic: String?
    var author: String
    
    // MARK: - Story Format
    var format: StoryFormat
    var difficultyLevel: Int
    var category: StoryCategory
    var tags: [String]?
    
    // MARK: - Media
    var coverImageURL: String?
    var audioNarrationURL: String?
    
    // MARK: - Content (Format-specific)
    var segments: [StorySegment]?           // For bilingual format (Level 2+)
    var mixedSegments: [MixedContentSegment]? // For mixed format (Level 1)
    var grammarNotes: [GrammarPoint]?
    
    // MARK: - Source Metadata
    var isUserCreated: Bool
    var isDownloaded: Bool
    var downloadDate: Date?
    var sourceURL: String?
    
    // MARK: - Progress Tracking
    var readingProgress: Double
    var currentSegmentIndex: Int
    var lastReadDate: Date?
    var completedWords: [String: Bool]?
    var learnedWordIds: [String]?          // Track learned words for mixed format
    var isBookmarked: Bool
    var totalReadingTime: TimeInterval
    
    // MARK: - Statistics
    var viewCount: Int
    var completionCount: Int
    var averageRating: Double?
    
    // MARK: - Timestamps
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case titleArabic
        case storyDescription
        case storyDescriptionArabic
        case author
        case format
        case difficultyLevel
        case category
        case tags
        case coverImageURL
        case audioNarrationURL
        case segments
        case mixedSegments
        case grammarNotes
        case isUserCreated
        case isDownloaded
        case downloadDate
        case sourceURL
        case readingProgress
        case currentSegmentIndex
        case lastReadDate
        case completedWords
        case learnedWordIds
        case isBookmarked
        case totalReadingTime
        case viewCount
        case completionCount
        case averageRating
        case createdAt
        case updatedAt
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        titleArabic: String? = nil,
        storyDescription: String,
        storyDescriptionArabic: String? = nil,
        author: String,
        format: StoryFormat = .bilingual,
        difficultyLevel: Int,
        category: StoryCategory = .general,
        tags: [String]? = nil,
        coverImageURL: String? = nil,
        audioNarrationURL: String? = nil,
        segments: [StorySegment]? = nil,
        mixedSegments: [MixedContentSegment]? = nil,
        grammarNotes: [GrammarPoint]? = nil,
        isUserCreated: Bool = false,
        isDownloaded: Bool = false,
        downloadDate: Date? = nil,
        sourceURL: String? = nil
    ) {
        self.id = id
        self.title = title
        self.titleArabic = titleArabic
        self.storyDescription = storyDescription
        self.storyDescriptionArabic = storyDescriptionArabic
        self.author = author
        self.format = format
        self.difficultyLevel = difficultyLevel
        self.category = category
        self.tags = tags
        self.coverImageURL = coverImageURL
        self.audioNarrationURL = audioNarrationURL
        self.segments = segments
        self.mixedSegments = mixedSegments
        self.grammarNotes = grammarNotes
        self.isUserCreated = isUserCreated
        self.isDownloaded = isDownloaded
        self.downloadDate = downloadDate
        self.sourceURL = sourceURL
        self.readingProgress = 0.0
        self.currentSegmentIndex = 0
        self.completedWords = [:]
        self.learnedWordIds = []
        self.isBookmarked = false
        self.totalReadingTime = 0
        self.viewCount = 0
        self.completionCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Computed Properties
    var isCompleted: Bool {
        readingProgress >= 1.0
    }
    
    var isNew: Bool {
        readingProgress == 0.0
    }
    var isInProgress: Bool {
        readingProgress > 0.0 && readingProgress < 1.0
    }
    
    var difficultyColor: String {
        switch difficultyLevel {
        case 1: return "green"
        case 2: return "teal"
        case 3: return "blue"
        case 4: return "orange"
        case 5: return "red"
        default: return "gray"
        }
    }
    
    var difficultyLabel: String {
        switch difficultyLevel {
        case 1: return "Beginner"
        case 2: return "Elementary"
        case 3: return "Intermediate"
        case 4: return "Advanced"
        case 5: return "Expert"
        default: return "Unknown"
        }
    }
    
    var wordCount: Int {
        arabicWordCount
    }
    
    var segmentCount: Int {
        switch format {
        case .mixed:
            return mixedSegments?.count ?? 0
        case .bilingual:
            return segments?.count ?? 0
        }
    }
    
    var estimatedReadingTime: TimeInterval {
        switch format {
        case .mixed:
            let totalWordCount = mixedSegments?.reduce(0) { $0 + $1.wordCount } ?? 0
            return Double(totalWordCount) / 150.0 * 60.0
        case .bilingual:
            let totalWordCount = segments?.reduce(0) { $0 + $1.wordCount } ?? 0
            return Double(totalWordCount) / 150.0 * 60.0
        }
    }
    
    // Vocabulary count - words found in story text that match Quran words
    var vocabularyCount: Int {
        arabicWordCount
    }
    
    /// Count of unique Arabic words found in the story text
    var arabicWordCount: Int {
        let allText: String
        switch format {
        case .mixed:
            allText = mixedSegments?.map { $0.text }.joined(separator: " ") ?? ""
        case .bilingual:
            allText = segments?.map { $0.arabicText }.joined(separator: " ") ?? ""
        }
        return extractArabicWords(from: allText).count
    }
    
    /// Extract unique Arabic words from text
    func extractArabicWords(from text: String) -> [String] {
        var words: [String] = []
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            let char = text[currentIndex]
            
            if ArabicTextUtils.isArabicCharacter(char) {
                var arabicWord = ""
                var endIndex = currentIndex
                
                while endIndex < text.endIndex &&
                      (ArabicTextUtils.isArabicCharacter(text[endIndex]) ||
                       ArabicTextUtils.isDiacritic(text[endIndex])) {
                    arabicWord.append(text[endIndex])
                    endIndex = text.index(after: endIndex)
                }
                
                if !arabicWord.isEmpty && !words.contains(arabicWord) {
                    words.append(arabicWord)
                }
                currentIndex = endIndex
            } else {
                currentIndex = text.index(after: currentIndex)
            }
        }
        
        return words
    }
    
    /// Get all Arabic words found in the story text
    var allArabicWordsInStory: [String] {
        let allText: String
        switch format {
        case .mixed:
            allText = mixedSegments?.map { $0.text }.joined(separator: " ") ?? ""
        case .bilingual:
            allText = segments?.map { $0.arabicText }.joined(separator: " ") ?? ""
        }
        return extractArabicWords(from: allText)
    }
    
    /// Find Quran words that exist in this story's text
    /// - Parameter quranWords: Array of QuranWord to search against
    /// - Returns: Array of QuranWord that match words in the story
    func findQuranWordsInStory(from quranWords: [QuranWord]) -> [QuranWord] {
        let storyWords = allArabicWordsInStory
        print("📖 Story '\(title)': Extracted \(storyWords.count) Arabic words: \(storyWords)")
        
        var matchedWords: [QuranWord] = []
        var seenIds: Set<String> = []
        
        for storyWord in storyWords {
            // Try to find matching Quran word
            if let match = quranWords.first(where: { quranWord in
                ArabicTextUtils.wordsMatch(quranWord.arabicText, storyWord)
            }) {
                print("📖   Matched: '\(storyWord)' -> '\(match.arabicText)' (\(match.englishMeaning))")
                if !seenIds.contains(match.id) {
                    matchedWords.append(match)
                    seenIds.insert(match.id)
                }
            } else {
                print("📖   No match for: '\(storyWord)'")
            }
        }
        
        print("📖 Story '\(title)': Total matches: \(matchedWords.count)")
        
        // Sort by rank (most common words first)
        return matchedWords.sorted { $0.rank < $1.rank }
    }
    
    // Learned vocabulary count
    var learnedVocabularyCount: Int {
        learnedWordIds?.count ?? 0
    }
    
    // MARK: - Progress Methods
    mutating func updateProgress(_ progress: Double) {
        readingProgress = min(max(progress, 0.0), 1.0)
        lastReadDate = Date()
        updatedAt = Date()
        
        if readingProgress >= 1.0 && !isCompleted {
            completionCount += 1
        }
    }
    
    mutating func markWordAsLearned(_ wordId: String) {
        if learnedWordIds == nil {
            learnedWordIds = []
        }
        if !(learnedWordIds?.contains(wordId) ?? false) {
            learnedWordIds?.append(wordId)
        }
        updatedAt = Date()
    }
    
    func isWordLearned(_ wordId: String) -> Bool {
        learnedWordIds?.contains(wordId) ?? false
    }
    
    mutating func incrementViewCount() {
        viewCount += 1
        updatedAt = Date()
    }
    
    mutating func resetProgress() {
        readingProgress = 0.0
        currentSegmentIndex = 0
        completedWords = [:]
        learnedWordIds = []
        totalReadingTime = 0
        updatedAt = Date()
    }
}

// MARK: - Story Category

enum StoryCategory: String, Codable, CaseIterable {
    case general = "general"
    case folktale = "folktale"
    case history = "history"
    case science = "science"
    case culture = "culture"
    case adventure = "adventure"
    case mystery = "mystery"
    case romance = "romance"
    case children = "children"
    case religious = "religious"
    case poetry = "poetry"
    case modern = "modern"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .general: return "book"
        case .folktale: return "sparkles"
        case .history: return "clock.arrow.circlepath"
        case .science: return "atom"
        case .culture: return "building.columns"
        case .adventure: return "compass"
        case .mystery: return "questionmark.circle"
        case .romance: return "heart"
        case .children: return "figure.child"
        case .religious: return "star.circle"
        case .poetry: return "quote.opening"
        case .modern: return "newspaper"
        }
    }
}

// MARK: - Story Segment (Bilingual Format - Level 2+)

struct StorySegment: Identifiable, Codable, Hashable {
    var id: UUID
    var index: Int
    var arabicText: String
    var englishText: String
    var transliteration: String?
    
    // Audio synchronization
    var audioStartTime: TimeInterval?
    var audioEndTime: TimeInterval?
    
    // Word timing for highlighting
    var wordTimings: [WordTiming]?
    
    // Media
    var imageURL: String?
    
    // Translation notes
    var culturalNote: String?
    var grammarNote: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case index
        case arabicText = "arabicText"
        case englishText = "englishText"
        case transliteration
        case audioStartTime
        case audioEndTime
        case wordTimings
        case imageURL
        case culturalNote
        case grammarNote
    }
    
    init(
        id: UUID = UUID(),
        index: Int,
        arabicText: String,
        englishText: String,
        transliteration: String? = nil,
        audioStartTime: TimeInterval? = nil,
        audioEndTime: TimeInterval? = nil,
        wordTimings: [WordTiming]? = nil,
        imageURL: String? = nil,
        culturalNote: String? = nil,
        grammarNote: String? = nil
    ) {
        self.id = id
        self.index = index
        self.arabicText = arabicText
        self.englishText = englishText
        self.transliteration = transliteration
        self.audioStartTime = audioStartTime
        self.audioEndTime = audioEndTime
        self.wordTimings = wordTimings
        self.imageURL = imageURL
        self.culturalNote = culturalNote
        self.grammarNote = grammarNote
    }
    
    var wordCount: Int {
        arabicText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
}

// MARK: - Mixed Content Segment (Level 1)

struct MixedContentSegment: Identifiable, Codable, Hashable {
    var id: UUID
    var index: Int
    
    // Plain text content - admin will add Arabic word links separately in admin panel
    var text: String
    
    // Optional image for this segment
    var imageURL: String?
    
    // Optional cultural note
    var culturalNote: String?
    
    // Arabic word references added by admin (optional, can be empty initially)
    var linkedWordIds: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case index
        case text
        case imageURL
        case culturalNote
        case linkedWordIds
    }
    
    init(
        id: UUID = UUID(),
        index: Int,
        text: String,
        imageURL: String? = nil,
        culturalNote: String? = nil,
        linkedWordIds: [String]? = nil
    ) {
        self.id = id
        self.index = index
        self.text = text
        self.imageURL = imageURL
        self.culturalNote = culturalNote
        self.linkedWordIds = linkedWordIds
    }
    
    // Computed property to get word count for reading time estimation
    var wordCount: Int {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
    
    // Get all linked Arabic word IDs in this segment
    var arabicWordIds: [String] {
        linkedWordIds ?? []
    }
}

// MARK: - Word Timing for Audio Sync

struct WordTiming: Codable, Hashable {
    let word: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let wordId: String?
}

// MARK: - Grammar Point

struct GrammarPoint: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var explanation: String
    var exampleArabic: String
    var exampleEnglish: String
    var ruleCategory: GrammarCategory
    var createdAt: Date?
    
    init(
        id: UUID = UUID(),
        title: String,
        explanation: String,
        exampleArabic: String,
        exampleEnglish: String,
        ruleCategory: GrammarCategory
    ) {
        self.id = id
        self.title = title
        self.explanation = explanation
        self.exampleArabic = exampleArabic
        self.exampleEnglish = exampleEnglish
        self.ruleCategory = ruleCategory
        self.createdAt = Date()
    }
}

enum GrammarCategory: String, Codable, CaseIterable {
    case verbConjugation = "verb_conjugation"
    case nounCases = "noun_cases"
    case particles = "particles"
    case sentenceStructure = "sentence_structure"
    case derivedForms = "derived_forms"
    case idafa = "idafa"
    case conditional = "conditional"
    case emphasis = "emphasis"
    case negation = "negation"
    case question = "question"
    
    var displayName: String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
