//
//  Story.swift
//  Hikaya
//  Story model - Firebase compatible (no SwiftData)
//

import Foundation

struct Story: Identifiable, Codable, Hashable {
    // MARK: - Identification
    var id: UUID
    var title: String
    var titleArabic: String?
    var storyDescription: String
    var storyDescriptionArabic: String?
    var author: String
    
    // MARK: - Categorization
    var difficultyLevel: Int
    var category: StoryCategory
    var tags: [String]?
    
    // MARK: - Media
    var coverImageURL: String?
    var audioNarrationURL: String?
    
    // MARK: - Content
    var segments: [StorySegment]?
    var words: [Word]?
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
        case difficultyLevel
        case category
        case tags
        case coverImageURL
        case audioNarrationURL
        case segments
        case words
        case grammarNotes
        case isUserCreated
        case isDownloaded
        case downloadDate
        case sourceURL
        case readingProgress
        case currentSegmentIndex
        case lastReadDate
        case completedWords
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
        difficultyLevel: Int,
        category: StoryCategory = .general,
        tags: [String]? = nil,
        coverImageURL: String? = nil,
        audioNarrationURL: String? = nil,
        segments: [StorySegment]? = nil,
        words: [Word]? = nil,
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
        self.difficultyLevel = difficultyLevel
        self.category = category
        self.tags = tags
        self.coverImageURL = coverImageURL
        self.audioNarrationURL = audioNarrationURL
        self.segments = segments
        self.words = words
        self.grammarNotes = grammarNotes
        self.isUserCreated = isUserCreated
        self.isDownloaded = isDownloaded
        self.downloadDate = downloadDate
        self.sourceURL = sourceURL
        self.readingProgress = 0.0
        self.currentSegmentIndex = 0
        self.completedWords = [:]
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
        words?.count ?? 0
    }
    
    var segmentCount: Int {
        segments?.count ?? 0
    }
    
    var estimatedReadingTime: TimeInterval {
        let totalWordCount = segments?.reduce(0) { $0 + $1.wordCount } ?? 0
        return Double(totalWordCount) / 150.0 * 60.0
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
        if completedWords == nil {
            completedWords = [:]
        }
        completedWords?[wordId] = true
        updatedAt = Date()
    }
    
    func isWordLearned(_ wordId: String) -> Bool {
        completedWords?[wordId] ?? false
    }
    
    mutating func incrementViewCount() {
        viewCount += 1
        updatedAt = Date()
    }
    
    mutating func resetProgress() {
        readingProgress = 0.0
        currentSegmentIndex = 0
        completedWords = [:]
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

// MARK: - Story Segment

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
    var createdAt: Date
    
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
