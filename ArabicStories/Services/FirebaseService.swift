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
    
    // MARK: - Quran Words (quran_words collection)
    
    /// Fetch words from quran_words collection with pagination
    func fetchQuranWords(
        limit: Int = 100,
        offset: Int = 0,
        sort: String = "rank",
        pos: String? = nil,
        form: String? = nil
    ) async throws -> (words: [QuranWord], total: Int) {
        print("📚 Fetching Quran words from Firestore... (offset: \(offset), limit: \(limit))")
        
        do {
            var query: Query = db.collection("quran_words")
            
            // Apply filters
            if let pos = pos {
                query = query.whereField("morphology.partOfSpeech", isEqualTo: pos)
            }
            if let form = form {
                query = query.whereField("morphology.form", isEqualTo: form)
            }
            
            // Apply sorting
            let sortField = sort == "occurrenceCount" ? "occurrenceCount" :
                           sort == "arabicText" ? "arabicText" : "rank"
            let descending = sort == "occurrenceCount"
            
            query = query.order(by: sortField, descending: descending)
            
            // For rank-based pagination (most efficient for ordered data)
            // Calculate the starting rank based on offset
            // Since rank starts at 1, page 1 = ranks 1-100, page 2 = ranks 101-200, etc.
            let startRank = offset + 1
            let endRank = offset + limit
            
            // Add range filter for efficient pagination when sorting by rank
            if sort == "rank" && pos == nil && form == nil {
                query = query
                    .whereField("rank", isGreaterThanOrEqualTo: startRank)
                    .whereField("rank", isLessThanOrEqualTo: endRank)
            }
            
            let snapshot = try await query.limit(to: limit).getDocuments()
            print("✅ Got \(snapshot.documents.count) Quran words from Firestore")
            
            var words: [QuranWord] = []
            for doc in snapshot.documents {
                do {
                    let word = try convertToQuranWord(doc.data(), id: doc.documentID)
                    words.append(word)
                } catch {
                    print("❌ Failed to parse Quran word \(doc.documentID): \(error)")
                }
            }
            
            // Get total count from stats
            let stats = try? await fetchQuranStats()
            let total = stats?.totalUniqueWords ?? 18994
            
            print("📚 Returning \(words.count) Quran words (total: \(total))")
            return (words, total)
        } catch {
            print("❌ Firestore error fetching Quran words: \(error)")
            throw error
        }
    }
    
    /// Get a single Quran word by ID
    func fetchQuranWord(id: String) async throws -> QuranWord? {
        let doc = try await db.collection("quran_words").document(id).getDocument()
        guard let data = doc.data() else { return nil }
        return try convertToQuranWord(data, id: doc.documentID)
    }
    
    /// Search Quran words by Arabic text or English meaning
    func searchQuranWords(query: String, limit: Int = 100) async throws -> [QuranWord] {
        print("🔍 Searching Quran words for: '\(query)'")
        
        // Check if query contains Arabic characters
        let containsArabic = query.range(of: "[\\u0600-\\u06FF]", options: .regularExpression) != nil
        
        if containsArabic {
            // Search by arabicWithoutDiacritics for better matching
            let snapshot = try await db.collection("quran_words")
                .whereField("arabicWithoutDiacritics", isGreaterThanOrEqualTo: query)
                .whereField("arabicWithoutDiacritics", isLessThanOrEqualTo: query + "\u{f8ff}")
                .limit(to: limit)
                .getDocuments()
            
            let words = snapshot.documents.compactMap { try? convertToQuranWord($0.data(), id: $0.documentID) }
            print("✅ Found \(words.count) matching Quran words (Arabic search)")
            return words
        } else {
            // Search by englishMeaning (case-insensitive prefix search)
            let lowerQuery = query.lowercased()
            let snapshot = try await db.collection("quran_words")
                .whereField("englishMeaning", isGreaterThanOrEqualTo: lowerQuery)
                .whereField("englishMeaning", isLessThanOrEqualTo: lowerQuery + "\u{f8ff}")
                .limit(to: limit)
                .getDocuments()
            
            let words = snapshot.documents.compactMap { try? convertToQuranWord($0.data(), id: $0.documentID) }
            print("✅ Found \(words.count) matching Quran words (English search)")
            return words
        }
    }
    
    /// Get words by root
    func fetchWordsByRoot(root: String, limit: Int = 100) async throws -> [QuranWord] {
        let snapshot = try await db.collection("quran_words")
            .whereField("root.arabic", isEqualTo: root)
            .order(by: "rank")
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? convertToQuranWord($0.data(), id: $0.documentID) }
    }
    
    /// Find a Quran word by its Arabic text (exact match)
    func findQuranWordByArabic(_ arabicText: String) async throws -> QuranWord? {
        let normalizedText = ArabicTextUtils.normalizeForMatching(arabicText)
        
        // Search by arabicWithoutDiacritics for matching
        let snapshot = try await db.collection("quran_words")
            .whereField("arabicWithoutDiacritics", isEqualTo: normalizedText)
            .limit(to: 1)
            .getDocuments()
        
        return snapshot.documents.first.flatMap { try? convertToQuranWord($0.data(), id: $0.documentID) }
    }
    
    /// Check if a word exists in quran_words (for highlighting)
    func isWordInQuranWords(_ arabicText: String) async throws -> Bool {
        let normalizedText = ArabicTextUtils.normalizeForMatching(arabicText)
        
        let snapshot = try await db.collection("quran_words")
            .whereField("arabicWithoutDiacritics", isEqualTo: normalizedText)
            .limit(to: 1)
            .getDocuments()
        
        return !snapshot.documents.isEmpty
    }
    
    // MARK: - Quran Stats (quran_stats collection)
    
    func fetchQuranStats() async throws -> QuranStats {
        let doc = try await db.collection("quran_stats").document("summary").getDocument()
        guard let data = doc.data() else {
            throw NSError(domain: "FirebaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Stats not found"])
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        return try JSONDecoder().decode(QuranStats.self, from: jsonData)
    }
    
    // MARK: - Quran Roots (quran_roots collection)
    
    func fetchQuranRoots(
        limit: Int = 100,
        offset: Int = 0,
        sort: String = "totalOccurrences"
    ) async throws -> (roots: [QuranRootDoc], total: Int) {
        print("🌳 Fetching Quran roots from Firestore...")
        
        var query: Query = db.collection("quran_roots")
        
        // Apply sorting
        switch sort {
        case "derivativeCount":
            query = query.order(by: "derivativeCount", descending: true)
        case "root":
            query = query.order(by: "root")
        default:
            query = query.order(by: "totalOccurrences", descending: true)
        }
        
        let snapshot = try await query.limit(to: limit).getDocuments()
        print("✅ Got \(snapshot.documents.count) Quran roots from Firestore")
        
        var roots: [QuranRootDoc] = []
        for doc in snapshot.documents {
            do {
                let root = try convertToQuranRootDoc(doc.data(), id: doc.documentID)
                roots.append(root)
            } catch {
                print("❌ Failed to parse root \(doc.documentID): \(error)")
            }
        }
        
        // Get total count from stats
        let stats = try? await fetchQuranStats()
        let total = stats?.uniqueRoots ?? 1651
        
        print("🌳 Returning \(roots.count) roots (total: \(total))")
        return (roots, total)
    }
    
    func fetchQuranRoot(id: String) async throws -> QuranRootDoc? {
        let doc = try await db.collection("quran_roots").document(id).getDocument()
        guard let data = doc.data() else { return nil }
        return try convertToQuranRootDoc(data, id: doc.documentID)
    }
    
    // MARK: - Legacy Generic Words (for backward compatibility)
    
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
    
    // MARK: - Word Mastery

    func saveWordMastery(_ mastery: [UUID: WordMastery], userId: String) async throws {
        print("💾 FirebaseService: Saving word mastery for user \(userId)")
        let encoder = JSONEncoder()
        let data = try encoder.encode(mastery)
        let jsonObject = try JSONSerialization.jsonObject(with: data)

        try await db.collection("users").document(userId).setData([
            "wordMastery": jsonObject
        ], merge: true)
        print("💾 FirebaseService: Successfully saved \(mastery.count) word mastery entries to Firestore")
    }

    func fetchWordMastery(userId: String) async throws -> [UUID: WordMastery] {
        print("📂 FirebaseService: Fetching word mastery for user \(userId)")
        let doc = try await db.collection("users").document(userId).getDocument()
        
        guard doc.exists else {
            print("📂 FirebaseService: User document does not exist, returning empty mastery")
            return [:]
        }
        
        guard let data = doc.data(),
              let wordMasteryData = data["wordMastery"] else {
            print("📂 FirebaseService: No wordMastery field found in user document, returning empty")
            return [:]
        }

        let jsonData = try JSONSerialization.data(withJSONObject: wordMasteryData)
        let decoder = JSONDecoder()
        let mastery = try decoder.decode([UUID: WordMastery].self, from: jsonData)
        print("📂 FirebaseService: Successfully loaded \(mastery.count) word mastery entries from Firestore")
        return mastery
    }
    
    // MARK: - Unlocked Words (New Optimized Structure)
    
    /// Save unlocked words for a user (called when story is completed)
    func saveUnlockedWords(_ words: [UnlockedWord], userId: String) async throws {
        let batch = db.batch()
        let unlockedWordsRef = db.collection("users").document(userId).collection("unlockedWords")
        
        for word in words {
            let wordRef = unlockedWordsRef.document(word.id.uuidString)
            let wordData = try word.toFirestore()
            batch.setData(wordData, forDocument: wordRef, merge: true)
        }
        
        try await batch.commit()
        print("💾 Saved \(words.count) unlocked words to Firebase for user")
    }
    
    /// Fetch all unlocked words for a user (FAST - single collection query)
    func fetchUnlockedWords(userId: String) async throws -> [UnlockedWord] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("unlockedWords")
            .order(by: "unlockedAt", descending: true)
            .getDocuments()
        
        var words: [UnlockedWord] = []
        for document in snapshot.documents {
            do {
                let word = try UnlockedWord.fromFirestore(document.data())
                words.append(word)
            } catch {
                print("⚠️ Failed to parse unlocked word \(document.documentID): \(error)")
            }
        }
        
        print("📚 Fetched \(words.count) unlocked words from Firebase")
        return words
    }
    
    /// Add a single unlocked word (for manual unlock or individual updates)
    func addUnlockedWord(_ word: UnlockedWord, userId: String) async throws {
        let wordRef = db.collection("users")
            .document(userId)
            .collection("unlockedWords")
            .document(word.id.uuidString)
        
        let wordData = try word.toFirestore()
        try await wordRef.setData(wordData, merge: true)
        print("💾 Added unlocked word: \(word.arabicText)")
    }
    
    /// Check if a word is already unlocked (to avoid duplicates)
    func isWordUnlocked(_ wordId: UUID, userId: String) async throws -> Bool {
        let doc = try await db.collection("users")
            .document(userId)
            .collection("unlockedWords")
            .document(wordId.uuidString)
            .getDocument()
        
        return doc.exists
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
            print("   Words from Firestore: \(story.words?.count ?? 0)")
            print("   Arabic words in text: \(story.allArabicWordsInStory.count)")
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
    
    // MARK: - Quran Data Conversion Helpers
    
    private func convertToQuranWord(_ data: [String: Any], id: String) throws -> QuranWord {
        var jsonDict = data
        jsonDict["id"] = id
        
        // Ensure required fields have defaults
        if jsonDict["rank"] == nil {
            jsonDict["rank"] = 0
        }
        if jsonDict["occurrenceCount"] == nil {
            jsonDict["occurrenceCount"] = 0
        }
        if jsonDict["arabicWithoutDiacritics"] == nil {
            jsonDict["arabicWithoutDiacritics"] = jsonDict["arabicText"] ?? ""
        }
        
        // Handle morphology null values
        if var morphology = jsonDict["morphology"] as? [String: Any] {
            if morphology["passive"] == nil {
                morphology["passive"] = false
            }
            jsonDict["morphology"] = morphology
        } else {
            // Create default morphology
            jsonDict["morphology"] = [
                "partOfSpeech": NSNull(),
                "posDescription": NSNull(),
                "lemma": NSNull(),
                "form": NSNull(),
                "tense": NSNull(),
                "gender": NSNull(),
                "number": NSNull(),
                "grammaticalCase": NSNull(),
                "passive": false,
                "breakdown": NSNull()
            ]
        }
        
        // Handle root null values
        if var root = jsonDict["root"] as? [String: Any] {
            if root["arabic"] is NSNull {
                root["arabic"] = nil
            }
            if root["transliteration"] is NSNull {
                root["transliteration"] = nil
            }
            jsonDict["root"] = root
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: jsonDict)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return try decoder.decode(QuranWord.self, from: jsonData)
    }
    
    private func convertToQuranRootDoc(_ data: [String: Any], id: String) throws -> QuranRootDoc {
        var jsonDict = data
        jsonDict["id"] = id
        
        let jsonData = try JSONSerialization.data(withJSONObject: jsonDict)
        return try JSONDecoder().decode(QuranRootDoc.self, from: jsonData)
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
    
    func fetchAllStoryProgressForUser(userId: String) async throws -> [StoryProgress] {
        let snapshot = try await db.collection("users").document(userId)
            .collection("storyProgress").getDocuments()
        
        return snapshot.documents.compactMap { doc in
            guard let data = doc.data() as? [String: Any] else { return nil }
            return try? convertToStoryProgress(data)
        }
    }
    
    func saveStoryProgress(_ progress: StoryProgress) async throws {
        let data = try storyProgressToDictionary(progress)
        try await db.collection("users").document(progress.userId)
            .collection("storyProgress").document(progress.storyId).setData(data)
    }
    
    func fetchStoryProgressFromData(_ data: [String: Any]) throws -> StoryProgress {
        return try convertToStoryProgress(data)
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
    
    // MARK: - Story Completion Tracking API
    
    /// Call Firebase function to track story completion
    func trackStoryCompletion(
        userId: String,
        userName: String?,
        userEmail: String?,
        storyId: String,
        storyTitle: String,
        difficultyLevel: Int
    ) async throws {
        let url = URL(string: "https://us-central1-arabicstories-82611.cloudfunctions.net/api/completions/story")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "userId": userId,
            "userName": userName ?? "Anonymous",
            "userEmail": userEmail ?? "",
            "storyId": storyId,
            "storyTitle": storyTitle,
            "difficultyLevel": difficultyLevel
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to track story completion"])
        }
        
        print("✅ Story completion tracked: \(storyTitle)")
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
