//
//  Word.swift
//  Arabicly
//  Word model - Firebase compatible (no SwiftData)
//

import Foundation

struct Word: Identifiable, Codable, Hashable {
    // MARK: - Identification
    var id: UUID
    var arabicText: String
    var transliteration: String?
    var englishMeaning: String
    
    // MARK: - Linguistic Metadata
    var partOfSpeech: PartOfSpeech?
    var rootLetters: String?
    var tashkeel: String?
    
    // MARK: - Learning Content
    var exampleSentences: [ExampleSentence]?
    var audioPronunciationURL: String?
    var difficulty: Int
    
    // MARK: - SRS (Spaced Repetition) Fields
    var isBookmarked: Bool?
    var reviewCount: Int?
    var nextReviewDate: Date?
    var lastReviewDate: Date?
    var interval: Double?
    var easeFactor: Double?
    var masteryLevel: MasteryLevel?
    
    // MARK: - Quran Metadata (populated when word comes from Quran matching)
    var quranOccurrenceCount: Int?
    var quranRank: Int?

    // MARK: - Timestamps
    var createdAt: Date?
    var updatedAt: Date?
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case id
        case arabicText = "arabic"
        case transliteration
        case englishMeaning = "english"
        case partOfSpeech
        case rootLetters
        case tashkeel
        case exampleSentences
        case audioPronunciationURL
        case difficulty
        case isBookmarked
        case reviewCount
        case nextReviewDate
        case lastReviewDate
        case interval
        case easeFactor
        case masteryLevel
        case quranOccurrenceCount
        case quranRank
        case createdAt
        case updatedAt
    }
    
    // MARK: - Custom Decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        arabicText = try container.decode(String.self, forKey: .arabicText)
        transliteration = try container.decodeIfPresent(String.self, forKey: .transliteration)
        englishMeaning = try container.decode(String.self, forKey: .englishMeaning)
        partOfSpeech = try container.decodeIfPresent(PartOfSpeech.self, forKey: .partOfSpeech)
        rootLetters = try container.decodeIfPresent(String.self, forKey: .rootLetters)
        tashkeel = try container.decodeIfPresent(String.self, forKey: .tashkeel)
        exampleSentences = try container.decodeIfPresent([ExampleSentence].self, forKey: .exampleSentences)
        audioPronunciationURL = try container.decodeIfPresent(String.self, forKey: .audioPronunciationURL)
        difficulty = try container.decode(Int.self, forKey: .difficulty)
        isBookmarked = try container.decodeIfPresent(Bool.self, forKey: .isBookmarked) ?? false
        reviewCount = try container.decodeIfPresent(Int.self, forKey: .reviewCount) ?? 0
        nextReviewDate = try container.decodeIfPresent(Date.self, forKey: .nextReviewDate)
        lastReviewDate = try container.decodeIfPresent(Date.self, forKey: .lastReviewDate)
        interval = try container.decodeIfPresent(Double.self, forKey: .interval) ?? 0
        easeFactor = try container.decodeIfPresent(Double.self, forKey: .easeFactor) ?? 2.5
        masteryLevel = try container.decodeIfPresent(MasteryLevel.self, forKey: .masteryLevel) ?? .new
        quranOccurrenceCount = try container.decodeIfPresent(Int.self, forKey: .quranOccurrenceCount)
        quranRank = try container.decodeIfPresent(Int.self, forKey: .quranRank)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
    
    init(
        id: UUID = UUID(),
        arabicText: String,
        transliteration: String? = nil,
        englishMeaning: String,
        partOfSpeech: PartOfSpeech? = nil,
        rootLetters: String? = nil,
        tashkeel: String? = nil,
        exampleSentences: [ExampleSentence]? = nil,
        audioPronunciationURL: String? = nil,
        difficulty: Int = 1,
        isBookmarked: Bool? = false,
        reviewCount: Int? = 0,
        interval: Double? = 0,
        easeFactor: Double? = 2.5,
        masteryLevel: MasteryLevel? = .new,
        quranOccurrenceCount: Int? = nil,
        quranRank: Int? = nil
    ) {
        self.id = id
        self.arabicText = arabicText
        self.transliteration = transliteration
        self.englishMeaning = englishMeaning
        self.partOfSpeech = partOfSpeech
        self.rootLetters = rootLetters
        self.tashkeel = tashkeel
        self.exampleSentences = exampleSentences
        self.audioPronunciationURL = audioPronunciationURL
        self.difficulty = difficulty
        self.isBookmarked = isBookmarked
        self.reviewCount = reviewCount
        self.interval = interval
        self.easeFactor = easeFactor
        self.masteryLevel = masteryLevel
        self.quranOccurrenceCount = quranOccurrenceCount
        self.quranRank = quranRank
        self.createdAt = nil
        self.updatedAt = nil
    }
    
    // MARK: - Computed Properties
    var displayText: String {
        tashkeel ?? arabicText
    }
    
    var isDueForReview: Bool {
        guard let nextReview = nextReviewDate else { return masteryLevel == .new }
        return Date() >= nextReview
    }
    
    // MARK: - SRS Methods (SM-2 Algorithm)
    mutating func processReviewResponse(quality: ResponseQuality) {
        let q = quality.rawValue
        
        // Initialize SRS values if nil
        let currentEaseFactor = easeFactor ?? 2.5
        let currentInterval = interval ?? 0
        let currentReviewCount = reviewCount ?? 0
        let currentMasteryLevel = masteryLevel ?? .new
        
        // Update ease factor
        let qualityPenalty = 5 - q
        let easeAdjustment = 0.1 - Double(qualityPenalty) * (0.08 + Double(qualityPenalty) * 0.02)
        easeFactor = max(1.3, currentEaseFactor + easeAdjustment)
        
        // Update interval
        if q < 3 {
            interval = 0
            masteryLevel = .learning
        } else {
            if currentReviewCount == 0 {
                interval = 1
            } else if currentReviewCount == 1 {
                interval = 6
            } else {
                interval = round(currentInterval * currentEaseFactor)
            }
            masteryLevel = currentMasteryLevel.nextLevel()
        }
        
        reviewCount = currentReviewCount + 1
        lastReviewDate = Date()
        nextReviewDate = Calendar.current.date(byAdding: .day, value: Int(interval ?? 0), to: Date())
        updatedAt = Date()
    }
    
    mutating func resetSRS() {
        reviewCount = 0
        interval = 0
        easeFactor = 2.5
        masteryLevel = .new
        nextReviewDate = nil
        lastReviewDate = nil
    }
}

// MARK: - Supporting Types

enum PartOfSpeech: String, Codable, CaseIterable {
    case noun = "noun"
    case verb = "verb"
    case adjective = "adjective"
    case adverb = "adverb"
    case pronoun = "pronoun"
    case preposition = "preposition"
    case conjunction = "conjunction"
    case article = "article"
    case particle = "particle"
    case interjection = "interjection"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .noun: return "textformat"
        case .verb: return "bolt"
        case .adjective: return "paintbrush"
        case .adverb: return "speedometer"
        case .pronoun: return "person"
        case .preposition: return "arrow.right"
        case .conjunction: return "link"
        case .article: return "a.circle"
        case .particle: return "dot.radiowaves.left.and.right"
        case .interjection: return "exclamationmark.bubble"
        }
    }
}

enum MasteryLevel: String, Codable, CaseIterable {
    case new = "new"
    case learning = "learning"
    case familiar = "familiar"
    case mastered = "mastered"
    case known = "known"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var color: String {
        switch self {
        case .new: return "gray"
        case .learning: return "red"
        case .familiar: return "orange"
        case .mastered: return "blue"
        case .known: return "green"
        }
    }
    
    func nextLevel() -> MasteryLevel {
        switch self {
        case .new: return .learning
        case .learning: return .familiar
        case .familiar: return .mastered
        case .mastered, .known: return .known
        }
    }
}

enum ResponseQuality: Int, CaseIterable {
    case again = 0
    case hard = 3
    case good = 4
    case easy = 5
    
    var displayName: String {
        switch self {
        case .again: return "Again"
        case .hard: return "Hard"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }
    
    var color: String {
        switch self {
        case .again: return "red"
        case .hard: return "orange"
        case .good: return "blue"
        case .easy: return "green"
        }
    }
}

struct ExampleSentence: Identifiable, Codable, Hashable {
    var id: UUID
    var arabic: String
    var transliteration: String
    var english: String
    var audioURL: String?
    
    init(
        id: UUID = UUID(),
        arabic: String,
        transliteration: String,
        english: String,
        audioURL: String? = nil
    ) {
        self.id = id
        self.arabic = arabic
        self.transliteration = transliteration
        self.english = english
        self.audioURL = audioURL
    }
}
