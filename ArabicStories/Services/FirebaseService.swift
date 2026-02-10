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
        let snapshot = try await db.collection("stories").getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Story.self) }
    }
    
    func fetchStory(id: String) async throws -> Story? {
        let doc = try await db.collection("stories").document(id).getDocument()
        return try doc.data(as: Story.self)
    }
    
    func saveStory(_ story: Story) async throws {
        try db.collection("stories").document(story.id.uuidString).setData(from: story)
    }
    
    func deleteStory(id: String) async throws {
        try await db.collection("stories").document(id).delete()
    }
    
    // MARK: - Words
    
    func fetchWords(for storyId: String) async throws -> [Word] {
        let snapshot = try await db.collection("stories").document(storyId).collection("words").getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Word.self) }
    }
    
    func saveWord(_ word: Word, storyId: String) async throws {
        try db.collection("stories").document(storyId).collection("words").document(word.id.uuidString).setData(from: word)
    }
    
    // MARK: - User Progress
    
    func fetchUserProgress(userId: String) async throws -> UserProgress? {
        let doc = try await db.collection("users").document(userId).getDocument()
        return try doc.data(as: UserProgress.self)
    }
    
    func saveUserProgress(_ progress: UserProgress, userId: String) async throws {
        try db.collection("users").document(userId).setData(from: progress)
    }
    
    // MARK: - Search
    
    func searchStories(query: String) async throws -> [Story] {
        let snapshot = try await db.collection("stories")
            .whereField("title", isGreaterThanOrEqualTo: query)
            .whereField("title", isLessThanOrEqualTo: query + "\u{f8ff}")
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Story.self) }
    }
    
    func fetchStoriesByDifficulty(level: Int) async throws -> [Story] {
        let snapshot = try await db.collection("stories")
            .whereField("difficultyLevel", isEqualTo: level)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Story.self) }
    }
}

// MARK: - Firestore Decoding Extensions

extension DocumentSnapshot {
    func data<T: Decodable>(as type: T.Type) throws -> T? {
        guard exists else { return nil }
        let data = try JSONSerialization.data(withJSONObject: data() ?? [:])
        return try JSONDecoder().decode(T.self, from: data)
    }
}

extension DocumentReference {
    func setData<T: Encodable>(from object: T) throws {
        let data = try JSONEncoder().encode(object)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        setData(dict)
    }
}
