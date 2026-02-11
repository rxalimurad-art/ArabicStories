//
//  FirebaseService.swift
//  Hikaya
//  Firebase Firestore integration for cloud data storage
//

import Foundation
import FirebaseFirestore
import FirebaseStorage

@Observable
class FirebaseService {
    static let shared = FirebaseService()
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    // MARK: - Stories
    
    func fetchStories() async throws -> [Story] {
        print("📚 Fetching stories from Firestore...")
        
        do {
            let snapshot = try await db.collection("stories").getDocuments()
            print("✅ Got \(snapshot.documents.count) documents from Firestore")
            
            var stories: [Story] = []
            for doc in snapshot.documents {
                print("📄 Processing document: \(doc.documentID)")
                do {
                    let story = try convertToStory(doc.data(), id: doc.documentID)
                    stories.append(story)
                    print("✅ Parsed story: \(story.title)")
                } catch {
                    print("❌ Failed to parse story \(doc.documentID): \(error)")
                    print("   Data keys: \(doc.data().keys.sorted())")
                }
            }
            
            print("📚 Returning \(stories.count) stories")
            return stories
        } catch {
            print("❌ Firestore error: \(error)")
            throw error
        }
    }
    
    func fetchStory(id: String) async throws -> Story? {
        let doc = try await db.collection("stories").document(id).getDocument()
        guard let data = doc.data() else { return nil }
        return try convertToStory(data, id: doc.documentID)
    }
    
    func saveStory(_ story: Story) async throws {
        let data = try storyToDictionary(story)
        try await db.collection("stories").document(story.id.uuidString).setData(data)
    }
    
    func deleteStory(id: String) async throws {
        try await db.collection("stories").document(id).delete()
    }
    
    // MARK: - Words
    
    func fetchWords(for storyId: String) async throws -> [Word] {
        let snapshot = try await db.collection("stories").document(storyId).collection("words").getDocuments()
        return snapshot.documents.compactMap { try? convertToWord($0.data()) }
    }
    
    func saveWord(_ word: Word, storyId: String) async throws {
        let data = try wordToDictionary(word)
        try await db.collection("stories").document(storyId).collection("words").document(word.id.uuidString).setData(data)
    }
    
    // MARK: - Generic Words
    
    /// Fetch all generic words from the 'words' collection
    func fetchGenericWords() async throws -> [Word] {
        print("📚 Fetching generic words from Firestore...")
        
        do {
            let snapshot = try await db.collection("words").getDocuments()
            print("✅ Got \(snapshot.documents.count) generic words from Firestore")
            
            var words: [Word] = []
            for doc in snapshot.documents {
                do {
                    let word = try convertToWord(doc.data())
                    words.append(word)
                } catch {
                    print("❌ Failed to parse generic word \(doc.documentID): \(error)")
                }
            }
            
            print("📚 Returning \(words.count) generic words")
            return words
        } catch {
            print("❌ Firestore error fetching generic words: \(error)")
            throw error
        }
    }
    
    /// Search generic words by Arabic text (with normalization)
    func searchGenericWords(arabicText: String) async throws -> [Word] {
        print("🔍 Searching generic words for: '\(arabicText)'")
        
        // Fetch all and filter client-side with Arabic normalization
        let allWords = try await fetchGenericWords()
        
        let matches = allWords.filter { word in
            ArabicTextUtils.wordsMatch(word.arabicText, arabicText)
        }
        
        print("✅ Found \(matches.count) matching generic words")
        return matches
    }
    
    // MARK: - User Progress
    
    func fetchUserProgress(userId: String) async throws -> UserProgress? {
        let doc = try await db.collection("users").document(userId).getDocument()
        guard let data = doc.data() else { return nil }
        return try convertToUserProgress(data)
    }
    
    func saveUserProgress(_ progress: UserProgress, userId: String) async throws {
        let data = try userProgressToDictionary(progress)
        try await db.collection("users").document(userId).setData(data)
    }
    
    // MARK: - Search
    
    func searchStories(query: String) async throws -> [Story] {
        let snapshot = try await db.collection("stories")
            .whereField("title", isGreaterThanOrEqualTo: query)
            .whereField("title", isLessThanOrEqualTo: query + "\u{f8ff}")
            .getDocuments()
        return snapshot.documents.compactMap { try? convertToStory($0.data(), id: $0.documentID) }
    }
    
    func fetchStoriesByDifficulty(level: Int) async throws -> [Story] {
        let snapshot = try await db.collection("stories")
            .whereField("difficultyLevel", isEqualTo: level)
            .getDocuments()
        return snapshot.documents.compactMap { try? convertToStory($0.data(), id: $0.documentID) }
    }
    
    // MARK: - Data Conversion Helpers
    
    private func convertToStory(_ data: [String: Any], id: String) throws -> Story {
        var jsonDict = data
        jsonDict["id"] = id
        
        // Convert Firestore Timestamps to ISO8601 strings
        let dateFormatter = ISO8601DateFormatter()
        
        if let createdAt = data["createdAt"] as? Timestamp {
            jsonDict["createdAt"] = dateFormatter.string(from: createdAt.dateValue())
        }
        if let updatedAt = data["updatedAt"] as? Timestamp {
            jsonDict["updatedAt"] = dateFormatter.string(from: updatedAt.dateValue())
        }
        if let lastReadDate = data["lastReadDate"] as? Timestamp {
            jsonDict["lastReadDate"] = dateFormatter.string(from: lastReadDate.dateValue())
        }
        if let downloadDate = data["downloadDate"] as? Timestamp {
            jsonDict["downloadDate"] = dateFormatter.string(from: downloadDate.dateValue())
        }
        
        // Convert segments
        if let segments = data["segments"] as? [[String: Any]] {
            jsonDict["segments"] = segments.map { segment -> [String: Any] in
                var seg = segment
                if let start = segment["audioStartTime"] as? Timestamp {
                    seg["audioStartTime"] = start.seconds
                }
                if let end = segment["audioEndTime"] as? Timestamp {
                    seg["audioEndTime"] = end.seconds
                }
                return seg
            }
        }
        
        // Convert words
        if let words = data["words"] as? [[String: Any]] {
            jsonDict["words"] = words.map { word -> [String: Any] in
                var w = word
                // Map Firestore field names to Swift model field names
                if let arabic = word["arabic"] as? String {
                    w["arabicText"] = arabic
                }
                if let english = word["english"] as? String {
                    w["englishMeaning"] = english
                }
                if let pos = word["partOfSpeech"] as? String {
                    w["partOfSpeech"] = pos
                } else {
                    w["partOfSpeech"] = nil
                }
                // Handle null values
                if word["transliteration"] is NSNull {
                    w["transliteration"] = nil
                }
                if word["partOfSpeech"] is NSNull {
                    w["partOfSpeech"] = nil
                }
                
                // Convert Firestore Timestamps in words to ISO8601 strings
                let dateFormatter = ISO8601DateFormatter()
                if let createdAt = word["createdAt"] as? Timestamp {
                    w["createdAt"] = dateFormatter.string(from: createdAt.dateValue())
                }
                if let updatedAt = word["updatedAt"] as? Timestamp {
                    w["updatedAt"] = dateFormatter.string(from: updatedAt.dateValue())
                }
                if let nextReviewDate = word["nextReviewDate"] as? Timestamp {
                    w["nextReviewDate"] = dateFormatter.string(from: nextReviewDate.dateValue())
                }
                if let lastReviewDate = word["lastReviewDate"] as? Timestamp {
                    w["lastReviewDate"] = dateFormatter.string(from: lastReviewDate.dateValue())
                }
                
                // Convert example sentences timestamps if present
                if let exampleSentences = word["exampleSentences"] as? [[String: Any]] {
                    w["exampleSentences"] = exampleSentences.map { sentence -> [String: Any] in
                        var s = sentence
                        if sentence["audioURL"] is NSNull {
                            s["audioURL"] = nil
                        }
                        return s
                    }
                }
                
                return w
            }
        }
        
        // Convert grammar notes timestamps
        if let grammarNotes = data["grammarNotes"] as? [[String: Any]] {
            jsonDict["grammarNotes"] = grammarNotes.map { note -> [String: Any] in
                var n = note
                if let createdAt = note["createdAt"] as? Timestamp {
                    n["createdAt"] = ISO8601DateFormatter().string(from: createdAt.dateValue())
                }
                return n
            }
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: jsonDict)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Story.self, from: jsonData)
    }
    
    private func storyToDictionary(_ story: Story) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(story)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    private func convertToWord(_ data: [String: Any]) throws -> Word {
        var jsonDict = data
        // Map Firestore field names to Swift model field names
        if let arabic = data["arabic"] as? String {
            jsonDict["arabicText"] = arabic
        }
        if let english = data["english"] as? String {
            jsonDict["englishMeaning"] = english
        }
        // Handle null values
        if data["transliteration"] is NSNull {
            jsonDict["transliteration"] = nil
        }
        if data["partOfSpeech"] is NSNull {
            jsonDict["partOfSpeech"] = nil
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: jsonDict)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Word.self, from: jsonData)
    }
    
    private func wordToDictionary(_ word: Word) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(word)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    private func convertToUserProgress(_ data: [String: Any]) throws -> UserProgress {
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(UserProgress.self, from: jsonData)
    }
    
    private func userProgressToDictionary(_ progress: UserProgress) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(progress)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}
