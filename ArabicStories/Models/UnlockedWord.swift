//
//  UnlockedWord.swift
//  Arabicly
//  Model for tracking user's unlocked words from completed stories
//

import Foundation

struct UnlockedWord: Identifiable, Codable {
    // MARK: - Properties
    let id: UUID                    // Word ID (same as Word.id)
    let wordData: Word              // Full word object with all data
    let unlockedAt: Date            // When this word was unlocked
    let fromStoryId: String         // ID of story that unlocked this word
    let fromStoryTitle: String      // Title for display
    let difficultyLevel: Int        // Story difficulty level
    
    init(
        id: UUID,
        wordData: Word,
        unlockedAt: Date = Date(),
        fromStoryId: String,
        fromStoryTitle: String,
        difficultyLevel: Int
    ) {
        self.id = id
        self.wordData = wordData
        self.unlockedAt = unlockedAt
        self.fromStoryId = fromStoryId
        self.fromStoryTitle = fromStoryTitle
        self.difficultyLevel = difficultyLevel
    }
    
    // MARK: - Convenience Properties
    
    var word: Word {
        wordData
    }
    
    var arabicText: String {
        wordData.arabicText
    }
    
    var englishMeaning: String {
        wordData.englishMeaning
    }
}

// MARK: - Firebase Conversion Helpers

extension UnlockedWord {
    /// Convert to Firestore dictionary
    func toFirestore() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let wordDataJSON = try encoder.encode(wordData)
        let wordDataDict = try JSONSerialization.jsonObject(with: wordDataJSON) as? [String: Any] ?? [:]
        
        return [
            "id": id.uuidString,
            "wordData": wordDataDict,
            "unlockedAt": unlockedAt,
            "fromStoryId": fromStoryId,
            "fromStoryTitle": fromStoryTitle,
            "difficultyLevel": difficultyLevel
        ]
    }
    
    /// Create from Firestore dictionary
    static func fromFirestore(_ data: [String: Any]) throws -> UnlockedWord {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let wordDataDict = data["wordData"] as? [String: Any],
              let fromStoryId = data["fromStoryId"] as? String,
              let fromStoryTitle = data["fromStoryTitle"] as? String,
              let difficultyLevel = data["difficultyLevel"] as? Int else {
            throw NSError(domain: "UnlockedWord", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid UnlockedWord data"])
        }
        
        // Convert wordData back to Word object
        let wordDataJSON = try JSONSerialization.data(withJSONObject: wordDataDict)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let wordData = try decoder.decode(Word.self, from: wordDataJSON)
        
        // Handle unlocked date (might be Firestore Timestamp or Date)
        let unlockedAt: Date
        if let timestamp = data["unlockedAt"] as? Date {
            unlockedAt = timestamp
        } else if let timestampValue = data["unlockedAt"] as? [String: Any],
                  let seconds = timestampValue["seconds"] as? TimeInterval {
            unlockedAt = Date(timeIntervalSince1970: seconds)
        } else {
            unlockedAt = Date()
        }
        
        return UnlockedWord(
            id: id,
            wordData: wordData,
            unlockedAt: unlockedAt,
            fromStoryId: fromStoryId,
            fromStoryTitle: fromStoryTitle,
            difficultyLevel: difficultyLevel
        )
    }
}
