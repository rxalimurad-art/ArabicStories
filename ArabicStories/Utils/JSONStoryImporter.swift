//
//  JSONStoryImporter.swift
//  Hikaya
//  Validates and imports stories from JSON to SwiftData
//

import Foundation
import SwiftData

class JSONStoryImporter {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - Main Import Function
    
    func importStories(from jsonData: Data) async throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        // Decode JSON
        let storyDTOs = try decoder.decode([StoryDTO].self, from: jsonData)
        
        var storiesImported = 0
        var wordsImported = 0
        var errors: [ImportError] = []
        
        // Process each story
        for dto in storyDTOs {
            do {
                // Check for duplicates
                if let existingId = dto.id,
                   let uuid = UUID(uuidString: existingId),
                   try await storyExists(id: uuid) {
                    errors.append(ImportError(
                        message: "Story with ID \(existingId) already exists",
                        context: dto.title
                    ))
                    continue
                }
                
                // Create story from DTO
                let story = try await createStory(from: dto)
                context.insert(story)
                
                storiesImported += 1
                wordsImported += story.words?.count ?? 0
                
            } catch {
                errors.append(ImportError(
                    message: error.localizedDescription,
                    context: dto.title
                ))
            }
        }
        
        // Save context
        try context.save()
        
        return ImportResult(
            storiesImported: storiesImported,
            wordsImported: wordsImported,
            errors: errors
        )
    }
    
    // MARK: - Story Creation
    
    private func createStory(from dto: StoryDTO) async throws -> Story {
        // Create segments
        let segments = dto.segments.map { segmentDTO in
            createSegment(from: segmentDTO)
        }
        
        // Create vocabulary words
        var words: [Word] = []
        if let vocabDTOs = dto.vocabulary {
            words = vocabDTOs.map { createWord(from: $0) }
        }
        
        // Create grammar notes
        var grammarNotes: [GrammarPoint] = []
        if let grammarDTOs = dto.grammarNotes {
            grammarNotes = grammarDTOs.map { createGrammarPoint(from: $0) }
        }
        
        // Create story
        let story = Story(
            id: dto.id.flatMap { UUID(uuidString: $0) } ?? UUID(),
            title: dto.title,
            titleArabic: dto.titleArabic,
            storyDescription: dto.description,
            storyDescriptionArabic: dto.descriptionArabic,
            author: dto.author,
            difficultyLevel: dto.difficultyLevel,
            category: StoryCategory(rawValue: dto.category ?? "general") ?? .general,
            tags: dto.tags,
            coverImageURL: dto.coverImageURL,
            audioNarrationURL: dto.audioNarrationURL,
            segments: segments,
            words: words,
            grammarNotes: grammarNotes,
            isDownloaded: true,
            downloadDate: Date()
        )
        
        // Link relationships
        segments.forEach { $0.story = story }
        words.forEach { $0.stories?.append(story) }
        grammarNotes.forEach { $0.story = story }
        
        return story
    }
    
    // MARK: - Entity Creation Helpers
    
    private func createSegment(from dto: StorySegmentDTO) -> StorySegment {
        let wordTimings = dto.wordTimings?.map { timingDTO in
            WordTiming(
                word: timingDTO.word,
                startTime: timingDTO.startTime,
                endTime: timingDTO.endTime,
                wordId: timingDTO.wordId
            )
        }
        
        return StorySegment(
            index: dto.index,
            arabicText: dto.arabicText,
            englishText: dto.englishText,
            transliteration: dto.transliteration,
            audioStartTime: dto.audioStartTime,
            audioEndTime: dto.audioEndTime,
            wordTimings: wordTimings,
            imageURL: dto.imageURL,
            culturalNote: dto.culturalNote,
            grammarNote: dto.grammarNote
        )
    }
    
    private func createWord(from dto: WordDTO) -> Word {
        let exampleSentences = dto.exampleSentences?.map { sentenceDTO in
            ExampleSentence(
                arabic: sentenceDTO.arabic,
                transliteration: sentenceDTO.transliteration,
                english: sentenceDTO.english,
                audioURL: sentenceDTO.audioURL
            )
        }
        
        return Word(
            id: dto.id.flatMap { UUID(uuidString: $0) } ?? UUID(),
            arabicText: dto.arabicText,
            transliteration: dto.transliteration,
            englishMeaning: dto.englishMeaning,
            partOfSpeech: PartOfSpeech(rawValue: dto.partOfSpeech) ?? .noun,
            rootLetters: dto.rootLetters,
            tashkeel: dto.tashkeel,
            exampleSentences: exampleSentences,
            audioPronunciationURL: dto.audioPronunciationURL,
            difficulty: dto.difficulty
        )
    }
    
    private func createGrammarPoint(from dto: GrammarPointDTO) -> GrammarPoint {
        GrammarPoint(
            title: dto.title,
            explanation: dto.explanation,
            exampleArabic: dto.exampleArabic,
            exampleEnglish: dto.exampleEnglish,
            ruleCategory: GrammarCategory(rawValue: dto.ruleCategory) ?? .sentenceStructure
        )
    }
    
    // MARK: - Validation
    
    private func storyExists(id: UUID) async throws -> Bool {
        let descriptor = FetchDescriptor<Story>(
            predicate: #Predicate { $0.id == id }
        )
        let count = try context.fetchCount(descriptor)
        return count > 0
    }
    
    func validateJSON(_ jsonData: Data) -> ValidationResult {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let storyDTOs = try decoder.decode([StoryDTO].self, from: jsonData)
            var errors: [ValidationError] = []
            var warnings: [ValidationWarning] = []
            
            for (index, dto) in storyDTOs.enumerated() {
                // Validate required fields
                if dto.title.isEmpty {
                    errors.append(ValidationError(
                        field: "title",
                        message: "Title is required",
                        storyIndex: index
                    ))
                }
                
                if dto.author.isEmpty {
                    errors.append(ValidationError(
                        field: "author",
                        message: "Author is required",
                        storyIndex: index
                    ))
                }
                
                if dto.difficultyLevel < 1 || dto.difficultyLevel > 5 {
                    errors.append(ValidationError(
                        field: "difficultyLevel",
                        message: "Difficulty level must be between 1 and 5",
                        storyIndex: index
                    ))
                }
                
                if dto.segments.isEmpty {
                    errors.append(ValidationError(
                        field: "segments",
                        message: "Story must have at least one segment",
                        storyIndex: index
                    ))
                }
                
                // Validate segments
                for (segIndex, segment) in dto.segments.enumerated() {
                    if segment.arabicText.isEmpty {
                        errors.append(ValidationError(
                            field: "segments[\(segIndex)].arabicText",
                            message: "Arabic text is required",
                            storyIndex: index
                        ))
                    }
                    
                    if segment.englishText.isEmpty {
                        warnings.append(ValidationWarning(
                            field: "segments[\(segIndex)].englishText",
                            message: "English translation is empty",
                            storyIndex: index
                        ))
                    }
                }
                
                // Validate vocabulary
                if let vocabulary = dto.vocabulary {
                    for (vocabIndex, word) in vocabulary.enumerated() {
                        if word.arabicText.isEmpty {
                            errors.append(ValidationError(
                                field: "vocabulary[\(vocabIndex)].arabicText",
                                message: "Arabic text is required",
                                storyIndex: index
                            ))
                        }
                        
                        if word.englishMeaning.isEmpty {
                            errors.append(ValidationError(
                                field: "vocabulary[\(vocabIndex)].englishMeaning",
                                message: "English meaning is required",
                                storyIndex: index
                            ))
                        }
                    }
                }
            }
            
            return ValidationResult(
                isValid: errors.isEmpty,
                storyCount: storyDTOs.count,
                errors: errors,
                warnings: warnings
            )
            
        } catch {
            return ValidationResult(
                isValid: false,
                storyCount: 0,
                errors: [ValidationError(
                    field: "json",
                    message: "Invalid JSON format: \(error.localizedDescription)",
                    storyIndex: nil
                )],
                warnings: []
            )
        }
    }
}

// MARK: - Validation Types

struct ValidationResult {
    let isValid: Bool
    let storyCount: Int
    let errors: [ValidationError]
    let warnings: [ValidationWarning]
}

struct ValidationError: Identifiable {
    let id = UUID()
    let field: String
    let message: String
    let storyIndex: Int?
}

struct ValidationWarning: Identifiable {
    let id = UUID()
    let field: String
    let message: String
    let storyIndex: Int?
}

// MARK: - JSON Story Exporter

class JSONStoryExporter {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    func exportStories() async throws -> Data {
        let descriptor = FetchDescriptor<Story>()
        let stories = try context.fetch(descriptor)
        
        let storyDTOs = stories.map { story in
            StoryDTO(
                id: story.id.uuidString,
                title: story.title,
                titleArabic: story.titleArabic,
                description: story.storyDescription,
                descriptionArabic: story.storyDescriptionArabic,
                author: story.author,
                difficultyLevel: story.difficultyLevel,
                category: story.category.rawValue,
                tags: story.tags,
                coverImageURL: story.coverImageURL,
                audioNarrationURL: story.audioNarrationURL,
                segments: story.segments?.map { segment in
                    StorySegmentDTO(
                        index: segment.index,
                        arabicText: segment.arabicText,
                        englishText: segment.englishText,
                        transliteration: segment.transliteration,
                        audioStartTime: segment.audioStartTime,
                        audioEndTime: segment.audioEndTime,
                        wordTimings: segment.wordTimings?.map { timing in
                            WordTimingDTO(
                                word: timing.word,
                                startTime: timing.startTime,
                                endTime: timing.endTime,
                                wordId: timing.wordId
                            )
                        },
                        imageURL: segment.imageURL,
                        culturalNote: segment.culturalNote,
                        grammarNote: segment.grammarNote
                    )
                } ?? [],
                vocabulary: story.words?.map { word in
                    WordDTO(
                        id: word.id.uuidString,
                        arabicText: word.arabicText,
                        transliteration: word.transliteration,
                        englishMeaning: word.englishMeaning,
                        partOfSpeech: word.partOfSpeech.rawValue,
                        rootLetters: word.rootLetters,
                        tashkeel: word.tashkeel,
                        exampleSentences: word.exampleSentences?.map { sentence in
                            ExampleSentenceDTO(
                                arabic: sentence.arabic,
                                transliteration: sentence.transliteration,
                                english: sentence.english,
                                audioURL: sentence.audioURL
                            )
                        },
                        audioPronunciationURL: word.audioPronunciationURL,
                        difficulty: word.difficulty
                    )
                },
                grammarNotes: story.grammarNotes?.map { point in
                    GrammarPointDTO(
                        title: point.title,
                        explanation: point.explanation,
                        exampleArabic: point.exampleArabic,
                        exampleEnglish: point.exampleEnglish,
                        ruleCategory: point.ruleCategory.rawValue,
                        relatedWordIds: point.relatedWords?.map { $0.id.uuidString }
                    )
                }
            )
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(storyDTOs)
    }
}
