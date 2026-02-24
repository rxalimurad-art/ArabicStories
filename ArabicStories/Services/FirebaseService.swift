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
    
    // MARK: - Stories (Offline Mode)
    
    /// Stories are now loaded from offline bundle (JSON files in app bundle)
    /// This method is kept for backward compatibility but returns offline data
    func fetchStories() async throws -> [Story] {
        print("📚 Loading stories from offline bundle...")
        return OfflineDataService.shared.loadStories()
    }
    
    func fetchStory(id: String) async throws -> Story? {
        // Load from offline bundle instead of Firebase
        guard let uuid = UUID(uuidString: id) else { return nil }
        return OfflineDataService.shared.getStory(id: uuid)
    }
    
    func saveStory(_ story: Story) async throws {
        // Offline bundle is read-only; stories cannot be saved to bundle
        // User progress is still saved to Firebase
        print("⚠️ FirebaseService: saveStory not implemented for offline mode (bundle is read-only)")
    }
    
    func deleteStory(id: String) async throws {
        // Offline bundle is read-only; stories cannot be deleted from bundle
        print("⚠️ FirebaseService: deleteStory not implemented for offline mode (bundle is read-only)")
    }
    
    // MARK: - Words (Offline Mode)
    
    /// Words are now loaded from offline bundle with their stories
    func fetchWords(for storyId: String) async throws -> [Word] {
        // Load from offline bundle
        guard let uuid = UUID(uuidString: storyId),
              let story = OfflineDataService.shared.getStory(id: uuid) else {
            return []
        }
        return story.words ?? []
    }
    
    func saveWord(_ word: Word, storyId: String) async throws {
        // Offline bundle is read-only
        print("⚠️ FirebaseService: saveWord not implemented for offline mode (bundle is read-only)")
    }
    
    // MARK: - Quran Words (Offline Mode)
    
    /// Quran words are now loaded from offline bundle (JSON files in app bundle)
    /// These methods are kept for backward compatibility but return offline data
    
    func fetchQuranWords(
        limit: Int = 100,
        offset: Int = 0,
        sort: String = "rank",
        pos: String? = nil,
        form: String? = nil
    ) async throws -> (words: [QuranWord], total: Int) {
        print("📚 Loading Quran words from offline bundle...")
        
        // Load from offline bundle
        var allWords = OfflineDataService.shared.loadQuranWords()
        
        // Apply filters
        if let pos = pos {
            allWords = allWords.filter { $0.morphology.partOfSpeech == pos }
        }
        if let form = form {
            allWords = allWords.filter { $0.morphology.form == form }
        }
        
        // Apply sorting
        switch sort {
        case "occurrenceCount":
            allWords.sort { $0.occurrenceCount > $1.occurrenceCount }
        case "arabicText":
            allWords.sort { $0.arabicText < $1.arabicText }
        default:
            allWords.sort { $0.rank < $1.rank }
        }
        
        // Apply pagination
        let startIndex = offset
        let endIndex = min(offset + limit, allWords.count)
        let paginatedWords = startIndex < allWords.count ? Array(allWords[startIndex..<endIndex]) : []
        
        print("📚 Returning \(paginatedWords.count) Quran words from offline bundle")
        return (paginatedWords, allWords.count)
    }
    
    func fetchQuranWord(id: String) async throws -> QuranWord? {
        return OfflineDataService.shared.getQuranWord(id: id)
    }
    
    func searchQuranWords(query: String, limit: Int = 100) async throws -> [QuranWord] {
        print("🔍 Searching Quran words in offline bundle for: '\(query)'")
        let results = OfflineDataService.shared.searchQuranWords(query: query)
        print("✅ Found \(results.count) matching Quran words")
        return Array(results.prefix(limit))
    }
    
    func fetchWordsByRoot(root: String, limit: Int = 100) async throws -> [QuranWord] {
        let results = OfflineDataService.shared.getQuranWordsByRoot(root: root)
        return Array(results.prefix(limit))
    }
    
    func findQuranWordByArabic(_ arabicText: String) async throws -> QuranWord? {
        return OfflineDataService.shared.findQuranWordByArabic(arabicText)
    }
    
    func isWordInQuranWords(_ arabicText: String) async throws -> Bool {
        return OfflineDataService.shared.isWordInQuranWords(arabicText)
    }
    
    // MARK: - Quran Stats (Offline Mode)
    
    func fetchQuranStats() async throws -> QuranStats {
        return OfflineDataService.shared.getQuranStats()
    }
    
    // MARK: - Quran Roots (Offline Mode)
    
    func fetchQuranRoots(
        limit: Int = 100,
        offset: Int = 0,
        sort: String = "totalOccurrences"
    ) async throws -> (roots: [QuranRootDoc], total: Int) {
        print("🌳 Loading Quran roots from offline bundle...")
        
        // Get unique roots from offline bundle
        let allRoots = OfflineDataService.shared.getUniqueRoots()
        
        // Create QuranRootDoc objects
        var roots: [QuranRootDoc] = allRoots.map { root in
            let wordsWithRoot = OfflineDataService.shared.getQuranWordsByRoot(root: root)
            let totalOccurrences = wordsWithRoot.reduce(0) { $0 + $1.occurrenceCount }
            
            return QuranRootDoc(
                id: root,
                root: root,
                transliteration: root,
                derivativeCount: wordsWithRoot.count,
                totalOccurrences: totalOccurrences,
                sampleDerivatives: wordsWithRoot.prefix(3).map { $0.arabicText }
            )
        }
        
        // Apply sorting
        switch sort {
        case "derivativeCount":
            roots.sort { $0.derivativeCount > $1.derivativeCount }
        case "root":
            roots.sort { $0.root < $1.root }
        default:
            roots.sort { $0.totalOccurrences > $1.totalOccurrences }
        }
        
        // Apply pagination
        let startIndex = offset
        let endIndex = min(offset + limit, roots.count)
        let paginatedRoots = startIndex < roots.count ? Array(roots[startIndex..<endIndex]) : []
        
        print("🌳 Returning \(paginatedRoots.count) roots from offline bundle")
        return (paginatedRoots, roots.count)
    }
    
    func fetchQuranRoot(id: String) async throws -> QuranRootDoc? {
        let wordsWithRoot = OfflineDataService.shared.getQuranWordsByRoot(root: id)
        guard !wordsWithRoot.isEmpty else { return nil }
        
        let totalOccurrences = wordsWithRoot.reduce(0) { $0 + $1.occurrenceCount }
        return QuranRootDoc(
            id: id,
            root: id,
            transliteration: id,
            derivativeCount: wordsWithRoot.count,
            totalOccurrences: totalOccurrences,
            sampleDerivatives: wordsWithRoot.prefix(3).map { $0.arabicText }
        )
    }
    
    // MARK: - Legacy Generic Words (Offline Mode)
    
    func fetchGenericWords() async throws -> [Word] {
        print("📚 Loading generic words from offline bundle...")
        // Return all words from all stories
        let stories = OfflineDataService.shared.loadStories()
        let allWords = stories.compactMap { $0.words }.flatMap { $0 }
        print("📚 Returning \(allWords.count) generic words")
        return allWords
    }
    
    func searchGenericWords(arabicText: String) async throws -> [Word] {
        print("🔍 Searching generic words for: '\(arabicText)'")
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
        try await db.collection("users").document(userId).setData(data, merge: true)
        print("✅ FirebaseService: Saved user progress with merge=true to preserve other fields")
    }
    
    // MARK: - Word Mastery

    // MARK: - Word Mastery (String IDs for QuranWord)
    
    func saveWordMastery(_ mastery: [String: WordMastery], userId: String) async throws {
        print("💾 FirebaseService: Saving word mastery for user \(userId)")
        let encoder = JSONEncoder()
        let data = try encoder.encode(mastery)
        let jsonObject = try JSONSerialization.jsonObject(with: data)

        try await db.collection("users").document(userId).setData([
            "wordMastery": jsonObject
        ], merge: true)
        print("💾 FirebaseService: Successfully saved \(mastery.count) word mastery entries to Firestore")
    }

    func fetchWordMastery(userId: String) async throws -> [String: WordMastery] {
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
        
        // Try to decode as dictionary first (new format)
        if let masteryDict = try? decoder.decode([String: WordMastery].self, from: jsonData) {
            print("📂 FirebaseService: Successfully loaded \(masteryDict.count) word mastery entries (dictionary format)")
            return masteryDict
        }
        
        // Fall back to array format (old format) and convert to dictionary
        if let masteryArray = try? decoder.decode([WordMastery].self, from: jsonData) {
            let masteryDict = Dictionary(uniqueKeysWithValues: masteryArray.map { ($0.id, $0) })
            print("📂 FirebaseService: Successfully loaded \(masteryDict.count) word mastery entries (array format converted)")
            return masteryDict
        }
        
        print("📂 FirebaseService: Could not decode word mastery data, returning empty")
        return [:]
    }
    
    // MARK: - Learned Quran Words (New)
    
    func saveLearnedQuranWords(_ words: [QuranWord], userId: String) async throws {
        print("💾 FirebaseService: Saving \(words.count) learned Quran words for user \(userId)")
        let batch = db.batch()
        let learnedWordsRef = db.collection("users").document(userId).collection("learnedQuranWords")
        
        for word in words {
            let wordRef = learnedWordsRef.document(word.id)
            let data = try quranWordToDictionary(word)
            batch.setData(data, forDocument: wordRef, merge: true)
        }
        
        try await batch.commit()
        print("💾 FirebaseService: Successfully saved learned Quran words")
    }
    
    func addLearnedQuranWord(_ word: QuranWord, userId: String) async throws {
        print("💾 FirebaseService: Adding learned Quran word '\(word.arabicText)' for user \(userId)")
        let learnedWordsRef = db.collection("users").document(userId).collection("learnedQuranWords")
        let wordRef = learnedWordsRef.document(word.id)
        
        // Check if word already exists
        let doc = try await wordRef.getDocument()
        if doc.exists {
            print("📂 Word '\(word.arabicText)' already in learned vocabulary, skipping")
            return
        }
        
        let data = try quranWordToDictionary(word)
        try await wordRef.setData(data, merge: true)
        print("💾 FirebaseService: Successfully added '\(word.arabicText)' to learned vocabulary")
    }
    
    func isQuranWordLearned(_ wordId: String, userId: String) async throws -> Bool {
        let doc = try await db.collection("users")
            .document(userId)
            .collection("learnedQuranWords")
            .document(wordId)
            .getDocument()
        return doc.exists
    }
    
    func fetchLearnedQuranWords(userId: String) async throws -> [QuranWord] {
        print("📂 FirebaseService: Fetching learned Quran words for user \(userId)")
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("learnedQuranWords")
            .getDocuments()
        
        var words: [QuranWord] = []
        for doc in snapshot.documents {
            do {
                let word = try convertToQuranWord(doc.data(), id: doc.documentID)
                words.append(word)
            } catch {
                print("❌ Failed to parse learned Quran word \(doc.documentID): \(error)")
            }
        }
        print("📂 FirebaseService: Successfully loaded \(words.count) learned Quran words")
        return words
    }
    
    func updateLearnedQuranWordField(wordId: String, userId: String, field: String, value: Any) async throws {
        try await db.collection("users")
            .document(userId)
            .collection("learnedQuranWords")
            .document(wordId)
            .updateData([field: value])
    }
    
    private func quranWordToDictionary(_ word: QuranWord) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(word)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
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

    /// Update a single field on an unlocked word document
    func updateUnlockedWordField(wordId: UUID, userId: String, field: String, value: Any) async throws {
        try await db.collection("users")
            .document(userId)
            .collection("unlockedWords")
            .document(wordId.uuidString)
            .updateData([field: value])
    }

    // MARK: - Search (Offline Mode)
    
    func searchStories(query: String) async throws -> [Story] {
        return OfflineDataService.shared.searchStories(query: query)
    }
    
    func fetchStoriesByDifficulty(level: Int) async throws -> [Story] {
        return OfflineDataService.shared.getStoriesByDifficulty(level: level)
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
        
        // Convert Firestore Timestamps to ISO8601 strings
        let dateFormatter = ISO8601DateFormatter()
        
        if let createdAt = jsonDict["createdAt"] as? Timestamp {
            jsonDict["createdAt"] = dateFormatter.string(from: createdAt.dateValue())
        } else {
            jsonDict["createdAt"] = nil
        }
        
        if let updatedAt = jsonDict["updatedAt"] as? Timestamp {
            jsonDict["updatedAt"] = dateFormatter.string(from: updatedAt.dateValue())
        } else {
            jsonDict["updatedAt"] = nil
        }
        
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
                "breakdown": NSNull(),
                "state": NSNull()
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
            if root["meaning"] is NSNull {
                root["meaning"] = nil
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
        let url = URL(string: "https://arabicstories-82611.web.app/api/completions/story")!
        
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
