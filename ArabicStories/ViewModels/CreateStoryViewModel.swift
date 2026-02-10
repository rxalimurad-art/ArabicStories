//
//  CreateStoryViewModel.swift
//  Hikaya
//  ViewModel for creating and editing stories
//

import Foundation
import SwiftUI
import PhotosUI

@Observable
class CreateStoryViewModel {
    // Dependencies
    private let dataService = DataService.shared
    
    // Story Data
    var title = ""
    var titleArabic = ""
    var description = ""
    var descriptionArabic = ""
    var author = ""
    var difficultyLevel = 1
    var category: StoryCategory = .general
    var tags: [String] = []
    
    // Content
    var segments: [StorySegmentDraft] = []
    var vocabulary: [WordDraft] = []
    
    // Media
    var selectedCoverImage: PhotosPickerItem?
    var coverImageData: Data?
    var coverImageURL: String?
    
    // State
    var isLoading = false
    var isSaving = false
    var showSuccessAlert = false
    var errorMessage: String?
    var currentStep = CreationStep.content
    
    // Draft Types
    struct StorySegmentDraft: Identifiable {
        let id = UUID()
        var index: Int
        var arabicText = ""
        var englishText = ""
        var transliteration = ""
        var culturalNote = ""
        var grammarNote = ""
    }
    
    struct WordDraft: Identifiable {
        let id = UUID()
        var arabicText = ""
        var transliteration = ""
        var englishMeaning = ""
        var partOfSpeech: PartOfSpeech = .noun
        var rootLetters = ""
        var tashkeel = ""
        var difficulty = 1
        var exampleSentences: [ExampleSentenceDraft] = []
    }
    
    struct ExampleSentenceDraft: Identifiable {
        let id = UUID()
        var arabic = ""
        var transliteration = ""
        var english = ""
    }
    
    init() {
        // Start with one empty segment
        addSegment()
    }
    
    // MARK: - Validation
    
    var isValid: Bool {
        !title.isEmpty &&
        !author.isEmpty &&
        !description.isEmpty &&
        difficultyLevel >= 1 && difficultyLevel <= 5 &&
        !segments.isEmpty &&
        segments.allSatisfy { !$0.arabicText.isEmpty && !$0.englishText.isEmpty }
    }
    
    var validationErrors: [String] {
        var errors: [String] = []
        
        if title.isEmpty {
            errors.append("Title is required")
        }
        
        if author.isEmpty {
            errors.append("Author is required")
        }
        
        if description.isEmpty {
            errors.append("Description is required")
        }
        
        if segments.isEmpty {
            errors.append("At least one segment is required")
        }
        
        for (index, segment) in segments.enumerated() {
            if segment.arabicText.isEmpty {
                errors.append("Segment \(index + 1): Arabic text is required")
            }
            if segment.englishText.isEmpty {
                errors.append("Segment \(index + 1): English text is required")
            }
        }
        
        return errors
    }
    
    // MARK: - Segment Management
    
    func addSegment() {
        let newSegment = StorySegmentDraft(
            index: segments.count,
            arabicText: "",
            englishText: ""
        )
        segments.append(newSegment)
    }
    
    func removeSegment(at index: Int) {
        guard index < segments.count else { return }
        segments.remove(at: index)
        // Re-index remaining segments
        for i in index..<segments.count {
            segments[i].index = i
        }
    }
    
    func updateSegment(id: UUID, arabicText: String? = nil, englishText: String? = nil, transliteration: String? = nil) {
        if let index = segments.firstIndex(where: { $0.id == id }) {
            if let arabicText = arabicText {
                segments[index].arabicText = arabicText
            }
            if let englishText = englishText {
                segments[index].englishText = englishText
            }
            if let transliteration = transliteration {
                segments[index].transliteration = transliteration
            }
        }
    }
    
    func moveSegment(from source: IndexSet, to destination: Int) {
        segments.move(fromOffsets: source, toOffset: destination)
        // Re-index
        for (index, _) in segments.enumerated() {
            segments[index].index = index
        }
    }
    
    // MARK: - Vocabulary Management
    
    func addWord() {
        let newWord = WordDraft()
        vocabulary.append(newWord)
    }
    
    func removeWord(at index: Int) {
        guard index < vocabulary.count else { return }
        vocabulary.remove(at: index)
    }
    
    func updateWord(id: UUID, updates: (inout WordDraft) -> Void) {
        if let index = vocabulary.firstIndex(where: { $0.id == id }) {
            updates(&vocabulary[index])
        }
    }
    
    func addExampleSentence(to wordId: UUID) {
        if let index = vocabulary.firstIndex(where: { $0.id == wordId }) {
            let newSentence = ExampleSentenceDraft()
            vocabulary[index].exampleSentences.append(newSentence)
        }
    }
    
    // MARK: - Auto-Extract Vocabulary
    
    func autoExtractVocabulary() {
        // Simple extraction: find words that appear multiple times
        var wordFrequency: [String: Int] = [:]
        
        for segment in segments {
            let words = segment.arabicText
                .components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                .filter { !$0.isEmpty && $0.count > 2 }
            
            for word in words {
                wordFrequency[word, default: 0] += 1
            }
        }
        
        // Add words that appear more than once and aren't already in vocabulary
        let existingWords = Set(vocabulary.map { $0.arabicText })
        let frequentWords = wordFrequency
            .filter { $0.value > 1 && !existingWords.contains($0.key) }
            .sorted { $0.value > $1.value }
            .prefix(10)
        
        for (word, _) in frequentWords {
            let newWord = WordDraft(
                arabicText: word,
                difficulty: difficultyLevel
            )
            vocabulary.append(newWord)
        }
    }
    
    // MARK: - Tag Management
    
    func addTag(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
    }
    
    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
    
    // MARK: - Image Handling
    
    func loadSelectedImage() async {
        guard let selectedCoverImage = selectedCoverImage else { return }
        
        do {
            if let data = try await selectedCoverImage.loadTransferable(type: Data.self) {
                coverImageData = data
                // In a real app, you'd upload this to a server and get a URL
                // For now, we'll store it locally
                coverImageURL = saveImageLocally(data: data)
            }
        } catch {
            errorMessage = "Failed to load image: \(error.localizedDescription)"
        }
    }
    
    private func saveImageLocally(data: Data) -> String? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "story_cover_\(UUID().uuidString).jpg"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileURL.absoluteString
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
    
    // MARK: - Save Story
    
    func saveStory(asDraft: Bool = false) async -> Bool {
        guard isValid else {
            errorMessage = validationErrors.joined(separator: "\n")
            return false
        }
        
        isSaving = true
        defer { isSaving = false }
        
        // Create story segments
        let storySegments = segments.map { draft in
            StorySegment(
                index: draft.index,
                arabicText: draft.arabicText,
                englishText: draft.englishText,
                transliteration: draft.transliteration.isEmpty ? nil : draft.transliteration,
                culturalNote: draft.culturalNote.isEmpty ? nil : draft.culturalNote,
                grammarNote: draft.grammarNote.isEmpty ? nil : draft.grammarNote
            )
        }
        
        // Create vocabulary words
        let storyWords = vocabulary.map { draft in
            let examples = draft.exampleSentences.map { exDraft in
                ExampleSentence(
                    arabic: exDraft.arabic,
                    transliteration: exDraft.transliteration,
                    english: exDraft.english
                )
            }
            
            return Word(
                arabicText: draft.arabicText,
                transliteration: draft.transliteration,
                englishMeaning: draft.englishMeaning,
                partOfSpeech: draft.partOfSpeech,
                rootLetters: draft.rootLetters.isEmpty ? nil : draft.rootLetters,
                tashkeel: draft.tashkeel.isEmpty ? nil : draft.tashkeel,
                exampleSentences: examples.isEmpty ? nil : examples,
                difficulty: draft.difficulty
            )
        }
        
        // Create story
        let story = Story(
            title: title,
            titleArabic: titleArabic.isEmpty ? nil : titleArabic,
            storyDescription: description,
            storyDescriptionArabic: descriptionArabic.isEmpty ? nil : descriptionArabic,
            author: author,
            difficultyLevel: difficultyLevel,
            category: category,
            tags: tags.isEmpty ? nil : tags,
            coverImageURL: coverImageURL,
            segments: storySegments,
            words: storyWords,
            isUserCreated: true,
            isDownloaded: false
        )
        
        // Set up relationships
        storySegments.forEach { $0.story = story }
        storyWords.forEach { $0.stories?.append(story) }
        
        do {
            try await dataService.saveStory(story)
            showSuccessAlert = true
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Reset
    
    func reset() {
        title = ""
        titleArabic = ""
        description = ""
        descriptionArabic = ""
        author = ""
        difficultyLevel = 1
        category = .general
        tags = []
        segments = []
        vocabulary = []
        selectedCoverImage = nil
        coverImageData = nil
        coverImageURL = nil
        errorMessage = nil
        currentStep = .content
        
        addSegment()
    }
}

// MARK: - Creation Steps

enum CreationStep: String, CaseIterable {
    case content = "Content"
    case vocabulary = "Vocabulary"
    case preview = "Preview"
    
    var icon: String {
        switch self {
        case .content: return "doc.text"
        case .vocabulary: return "textformat.abc"
        case .preview: return "eye"
        }
    }
}
