//
//  FirebaseService.swift
//  Arabicly
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
            
            // Log all document IDs to check for duplicates at Firestore level
            let docIDs = snapshot.documents.map { $0.documentID }
            let normalizedDocIDs = docIDs.map { $0.lowercased() }
            let uniqueDocIDs = Set(normalizedDocIDs)
            print("📄 Firestore document IDs: \(docIDs)")
            print("📄 Normalized IDs: \(Array(uniqueDocIDs))")
            if normalizedDocIDs.count != uniqueDocIDs.count {
                print("⚠️ DUPLICATE DOCUMENT IDs IN FIRESTORE!")
            }
            
            var stories: [Story] = []
            
            for doc in snapshot.documents {
                print("📄 Processing document: \(doc.documentID)")
                do {
                    let story = try convertToStory(doc.data(), id: doc.documentID)
                    stories.append(story)
                    print("✅ Parsed story: '\(story.title)' [StoryID: \(story.id)]")
                } catch {
                    print("❌ Failed to parse story \(doc.documentID): \(error)")
                    print("   Data keys: \(doc.data().keys.sorted())")
                }
            }
            
            // Deduplicate stories by normalized ID
            let uniqueStories = deduplicateStories(stories)
            print("📚 Returning \(uniqueStories.count) unique stories from \(snapshot.documents.count) Firestore docs")
            return uniqueStories
        } catch {
            print("❌ Firestore error: \(error)")
            throw error
        }
    }
    
    func fetchStory(id: String) async throws -> Story? {
        // Use lowercase ID to ensure consistency
        let doc = try await db.collection("stories").document(id.lowercased()).getDocument()
        guard let data = doc.data() else { return nil }
        return try convertToStory(data, id: doc.documentID)
    }
    
    func saveStory(_ story: Story) async throws {
        let data = try storyToDictionary(story)
        // Use lowercase ID to ensure consistency
        let docID = story.id.uuidString.lowercased()
        try await db.collection("stories").document(docID).setData(data)
        print("💾 Saved story '\(story.title)' to Firestore document: \(docID)")
    }
    
    func deleteStory(id: String) async throws {
        // Use lowercase ID to ensure consistency
        try await db.collection("stories").document(id.lowercased()).delete()
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
        return deduplicateStories(snapshot.documents.compactMap { try? convertToStory($0.data(), id: $0.documentID) })
    }
    
    func fetchStoriesByDifficulty(level: Int) async throws -> [Story] {
        let snapshot = try await db.collection("stories")
            .whereField("difficultyLevel", isEqualTo: level)
            .getDocuments()
        return deduplicateStories(snapshot.documents.compactMap { try? convertToStory($0.data(), id: $0.documentID) })
    }
    
    // MARK: - Helper Functions
    
    private func deduplicateStories(_ stories: [Story]) -> [Story] {
        var seenIDs: Set<String> = []
        var uniqueStories: [Story] = []
        
        for story in stories {
            let id = story.id.uuidString.lowercased()
            if !seenIDs.contains(id) {
                seenIDs.insert(id)
                uniqueStories.append(story)
            } else {
                print("  🗑️ Deduplicating story '\(story.title)' with ID \(id)")
            }
        }
        
        if uniqueStories.count < stories.count {
            print("📊 Deduplicated: \(stories.count) -> \(uniqueStories.count) stories")
        }
        
        return uniqueStories
    }
    
    // MARK: - Data Conversion Helpers
    
    private func convertToStory(_ data: [String: Any], id: String) throws -> Story {
        var jsonDict = data
        
        // Normalize ID to lowercase to handle case-insensitive UUIDs
        let normalizedID = id.lowercased()
        
        // Handle ID - Firestore document ID might not be a valid UUID
        // Use the Firestore ID directly if it's a valid UUID, otherwise create deterministic UUID
        let finalUUID: UUID
        if let validUUID = UUID(uuidString: normalizedID) {
            finalUUID = validUUID
            jsonDict["id"] = validUUID.uuidString.lowercased()
            print("  📎 Firestore ID '\(id)' -> Normalized UUID: \(validUUID.uuidString.lowercased())")
        } else {
            // Create deterministic UUID from Firestore document ID
            let hash = normalizedID.md5()
            let uuidString = "\(hash.prefix(8))-\(hash.dropFirst(8).prefix(4))-4\(hash.dropFirst(12).prefix(3))-\(hash.dropFirst(15).prefix(4))-\(hash.dropFirst(19).prefix(12))"
            if let generatedUUID = UUID(uuidString: uuidString) {
                finalUUID = generatedUUID
                jsonDict["id"] = uuidString
                print("  📎 Firestore ID '\(id)' -> Generated UUID: \(uuidString)")
            } else {
                // Fallback - should never happen
                finalUUID = UUID()
                jsonDict["id"] = finalUUID.uuidString
                print("  ⚠️ Firestore ID '\(id)' -> Fallback UUID: \(finalUUID)")
            }
        }
        
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
        
        // Handle format field
        if let formatString = data["format"] as? String {
            jsonDict["format"] = formatString
        } else {
            // Default to bilingual if not specified
            jsonDict["format"] = "bilingual"
        }
        
        // Convert mixed segments (Level 1 format) - simplified: just text and linkedWordIds
        if let mixedSegments = data["mixedSegments"] as? [[String: Any]] {
            jsonDict["mixedSegments"] = mixedSegments.enumerated().map { index, segment -> [String: Any] in
                var seg = segment
                
                // Ensure segment has an ID
                if seg["id"] == nil || (seg["id"] as? String)?.isEmpty == true {
                    seg["id"] = UUID().uuidString
                }
                
                // Ensure segment has an index
                if seg["index"] == nil {
                    seg["index"] = index
                }
                
                // Handle text field (plain text content)
                if seg["text"] == nil {
                    seg["text"] = seg["content"] as? String ?? ""
                }
                
                // Handle linkedWordIds (Arabic words linked by admin)
                if seg["linkedWordIds"] == nil {
                    seg["linkedWordIds"] = []
                }
                
                return seg
            }
        }
        
        // Convert regular segments (Level 2+ format)
        if let segments = data["segments"] as? [[String: Any]] {
            jsonDict["segments"] = segments.enumerated().map { index, segment -> [String: Any] in
                var seg = segment
                
                // Ensure segment has an ID
                if seg["id"] == nil || (seg["id"] as? String)?.isEmpty == true {
                    seg["id"] = UUID().uuidString
                }
                
                // Ensure segment has an index
                if seg["index"] == nil {
                    seg["index"] = index
                }
                
                // Convert timestamps
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
                
                // Ensure word has an ID
                if w["id"] == nil || (w["id"] as? String)?.isEmpty == true {
                    w["id"] = UUID().uuidString
                }
                
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
        
        do {
            let story = try decoder.decode(Story.self, from: jsonData)
            print("✅ Successfully decoded story: \(story.title) [Format: \(story.format.rawValue)]")
            if story.format == .mixed {
                print("   Mixed segments: \(story.mixedSegments?.count ?? 0)")
            } else {
                print("   Bilingual segments: \(story.segments?.count ?? 0)")
            }
            print("   Words: \(story.words?.count ?? 0)")
            return story
        } catch {
            print("❌ Failed to decode Story: \(error)")
            print("   JSON keys: \(jsonDict.keys.sorted())")
            if let mixedSegments = jsonDict["mixedSegments"] as? [[String: Any]] {
                print("   Mixed segments count: \(mixedSegments.count)")
                for (i, seg) in mixedSegments.enumerated() {
                    print("   Segment \(i): \(seg.keys.sorted())")
                }
            }
            throw error
        }
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
        var jsonDict = data
        
        // Handle Firestore timestamps in user progress
        let dateFormatter = ISO8601DateFormatter()
        
        if let createdAt = data["createdAt"] as? Timestamp {
            jsonDict["createdAt"] = dateFormatter.string(from: createdAt.dateValue())
        }
        if let updatedAt = data["updatedAt"] as? Timestamp {
            jsonDict["updatedAt"] = dateFormatter.string(from: updatedAt.dateValue())
        }
        if let lastStudyDate = data["lastStudyDate"] as? Timestamp {
            jsonDict["lastStudyDate"] = dateFormatter.string(from: lastStudyDate.dateValue())
        }
        if let streakFreezeDate = data["streakFreezeDate"] as? Timestamp {
            jsonDict["streakFreezeDate"] = dateFormatter.string(from: streakFreezeDate.dateValue())
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: jsonDict)
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
    
    // MARK: - Story Progress (User-Specific)
    
    func fetchStoryProgress(storyId: String, userId: String) async throws -> StoryProgress? {
        let doc = try await db.collection("users").document(userId)
            .collection("storyProgress").document(storyId).getDocument()
        
        guard let data = doc.data() else { return nil }
        return try convertToStoryProgress(data)
    }
    
    func saveStoryProgress(_ progress: StoryProgress) async throws {
        let data = try storyProgressToDictionary(progress)
        try await db.collection("users").document(progress.userId)
            .collection("storyProgress").document(progress.storyId).setData(data)
    }
    
    private func convertToStoryProgress(_ data: [String: Any]) throws -> StoryProgress {
        var jsonDict = data
        
        // Handle Firestore timestamps
        let dateFormatter = ISO8601DateFormatter()
        
        if let lastReadDate = data["lastReadDate"] as? Timestamp {
            jsonDict["lastReadDate"] = dateFormatter.string(from: lastReadDate.dateValue())
        }
        if let completionDate = data["completionDate"] as? Timestamp {
            jsonDict["completionDate"] = dateFormatter.string(from: completionDate.dateValue())
        }
        if let startedAt = data["startedAt"] as? Timestamp {
            jsonDict["startedAt"] = dateFormatter.string(from: startedAt.dateValue())
        }
        if let updatedAt = data["updatedAt"] as? Timestamp {
            jsonDict["updatedAt"] = dateFormatter.string(from: updatedAt.dateValue())
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: jsonDict)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(StoryProgress.self, from: jsonData)
    }
    
    private func storyProgressToDictionary(_ progress: StoryProgress) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(progress)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

// MARK: - String Extension for MD5 Hashing

import CryptoKit

extension String {
    func md5() -> String {
        let data = Data(self.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
}
