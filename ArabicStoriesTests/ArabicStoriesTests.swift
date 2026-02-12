//
//  ArabicStoriesTests.swift
//  Arabicly Tests
//  Unit tests for data layer, models, and core functionality
//

import XCTest
import SwiftData
@testable import ArabicStories

@MainActor
final class ArabiclyTests: XCTestCase {
    
    // MARK: - Properties
    
    var container: ModelContainer!
    var context: ModelContext!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        
        let schema = Schema([
            Story.self,
            StorySegment.self,
            Word.self,
            ExampleSentence.self,
            GrammarPoint.self,
            UserProgress.self,
            Achievement.self
        ])
        
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
            context = ModelContext(container)
        } catch {
            XCTFail("Failed to create test container: \(error)")
        }
    }
    
    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }
    
    // MARK: - Story Tests
    
    func testStoryCreation() {
        let story = Story(
            title: "Test Story",
            description: "A test story description",
            author: "Test Author",
            difficultyLevel: 2
        )
        
        XCTAssertEqual(story.title, "Test Story")
        XCTAssertEqual(story.difficultyLevel, 2)
        XCTAssertEqual(story.readingProgress, 0.0)
        XCTAssertFalse(story.isCompleted)
    }
    
    func testStoryProgressUpdate() {
        let story = Story(
            title: "Test Story",
            description: "Description",
            author: "Author",
            difficultyLevel: 1
        )
        
        story.updateProgress(0.5)
        XCTAssertEqual(story.readingProgress, 0.5)
        XCTAssertTrue(story.isInProgress)
        XCTAssertFalse(story.isCompleted)
        
        story.updateProgress(1.0)
        XCTAssertEqual(story.readingProgress, 1.0)
        XCTAssertTrue(story.isCompleted)
    }
    
    func testStoryWordTracking() {
        let story = Story(
            title: "Test Story",
            description: "Description",
            author: "Author",
            difficultyLevel: 1
        )
        
        let wordId = "test-word-123"
        XCTAssertFalse(story.isWordLearned(wordId))
        
        story.markWordAsLearned(wordId)
        XCTAssertTrue(story.isWordLearned(wordId))
    }
    
    func testStoryDifficultyLabel() {
        let story1 = Story(title: "Test", description: "Desc", author: "Author", difficultyLevel: 1)
        let story3 = Story(title: "Test", description: "Desc", author: "Author", difficultyLevel: 3)
        let story5 = Story(title: "Test", description: "Desc", author: "Author", difficultyLevel: 5)
        
        XCTAssertEqual(story1.difficultyLabel, "Beginner")
        XCTAssertEqual(story3.difficultyLabel, "Intermediate")
        XCTAssertEqual(story5.difficultyLabel, "Expert")
    }
    
    // MARK: - Word Tests
    
    func testWordCreation() {
        let word = Word(
            arabicText: "كتاب",
            transliteration: "kitāb",
            englishMeaning: "book",
            partOfSpeech: .noun,
            rootLetters: "ك ت ب"
        )
        
        XCTAssertEqual(word.arabicText, "كتاب")
        XCTAssertEqual(word.englishMeaning, "book")
        XCTAssertEqual(word.partOfSpeech, .noun)
        XCTAssertEqual(word.masteryLevel, .new)
    }
    
    func testWordSRSProcessing() {
        let word = Word(
            arabicText: "test",
            transliteration: "test",
            englishMeaning: "test",
            partOfSpeech: .noun
        )
        
        // Test "again" response
        word.processReviewResponse(quality: .again)
        XCTAssertEqual(word.masteryLevel, .learning)
        XCTAssertEqual(word.reviewCount, 1)
        XCTAssertEqual(word.interval, 0)
        
        // Reset and test "good" response
        word.resetSRS()
        XCTAssertEqual(word.masteryLevel, .new)
        
        word.processReviewResponse(quality: .good)
        XCTAssertEqual(word.reviewCount, 1)
        XCTAssertEqual(word.interval, 1)
        XCTAssertEqual(word.masteryLevel, .learning)
    }
    
    func testWordDueForReview() {
        let word = Word(
            arabicText: "test",
            transliteration: "test",
            englishMeaning: "test",
            partOfSpeech: .noun
        )
        
        // New word should be due
        XCTAssertTrue(word.isDueForReview)
        
        // Word with future review date should not be due
        word.nextReviewDate = Date().addingTimeInterval(86400) // Tomorrow
        XCTAssertFalse(word.isDueForReview)
        
        // Word with past review date should be due
        word.nextReviewDate = Date().addingTimeInterval(-86400) // Yesterday
        XCTAssertTrue(word.isDueForReview)
    }
    
    // MARK: - User Progress Tests
    
    func testUserProgressStreak() {
        let progress = UserProgress()
        
        // Initial state
        XCTAssertEqual(progress.currentStreak, 0)
        XCTAssertNil(progress.lastStudyDate)
        
        // First study session
        progress.recordStudySession(minutes: 15)
        XCTAssertEqual(progress.currentStreak, 1)
        XCTAssertNotNil(progress.lastStudyDate)
        
        // Same day study - streak unchanged
        progress.recordStudySession(minutes: 10)
        XCTAssertEqual(progress.currentStreak, 1)
    }
    
    func testUserProgressWordTracking() {
        let progress = UserProgress()
        
        progress.recordWordLearned(wordId: "word1", isNew: true)
        XCTAssertEqual(progress.totalWordsLearned, 1)
        
        progress.recordWordLearned(wordId: "word1", isNew: false)
        // Should not increment for non-new word
        XCTAssertEqual(progress.totalWordsLearned, 1)
        
        progress.recordWordMastered(wordId: "word1")
        XCTAssertEqual(progress.totalWordsMastered, 1)
    }
    
    func testDailyGoalProgress() {
        let progress = UserProgress()
        progress.dailyGoalMinutes = 20
        progress.todayStudyMinutes = 10
        
        XCTAssertEqual(progress.dailyGoalProgress, 0.5)
        XCTAssertFalse(progress.isDailyGoalCompleted)
        
        progress.todayStudyMinutes = 25
        XCTAssertEqual(progress.dailyGoalProgress, 1.0)
        XCTAssertTrue(progress.isDailyGoalCompleted)
    }
    
    // MARK: - JSON Import Tests
    
    func testJSONValidation() {
        let importer = JSONStoryImporter(context: context)
        
        // Valid JSON
        let validJSON = """
        [{
            "title": "Test Story",
            "description": "A test story",
            "author": "Test Author",
            "difficulty_level": 1,
            "segments": [{
                "index": 0,
                "arabic_text": "مرحبا",
                "english_text": "Hello"
            }]
        }]
        """.data(using: .utf8)!
        
        let validResult = importer.validateJSON(validJSON)
        XCTAssertTrue(validResult.isValid)
        XCTAssertEqual(validResult.storyCount, 1)
        
        // Invalid JSON - missing required fields
        let invalidJSON = """
        [{
            "title": "",
            "description": "Test",
            "author": "",
            "difficulty_level": 1,
            "segments": []
        }]
        """.data(using: .utf8)!
        
        let invalidResult = importer.validateJSON(invalidJSON)
        XCTAssertFalse(invalidResult.isValid)
        XCTAssertGreaterThan(invalidResult.errors.count, 0)
    }
    
    func testJSONImport() async throws {
        let importer = JSONStoryImporter(context: context)
        
        let jsonData = """
        [{
            "id": "test-story-1",
            "title": "Test Story",
            "description": "A test story for import",
            "author": "Test Author",
            "difficulty_level": 2,
            "segments": [{
                "index": 0,
                "arabic_text": "مرحبا بالعالم",
                "english_text": "Hello world",
                "transliteration": "marhaba bil-alam"
            }],
            "vocabulary": [{
                "arabic_text": "مرحبا",
                "transliteration": "marhaba",
                "english_meaning": "hello",
                "part_of_speech": "noun",
                "difficulty": 1
            }]
        }]
        """.data(using: .utf8)!
        
        let result = try await importer.importStories(from: jsonData)
        
        XCTAssertEqual(result.storiesImported, 1)
        XCTAssertEqual(result.wordsImported, 1)
        XCTAssertEqual(result.errors.count, 0)
        
        // Verify story was created
        let descriptor = FetchDescriptor<Story>(
            predicate: #Predicate { $0.title == "Test Story" }
        )
        let stories = try context.fetch(descriptor)
        XCTAssertEqual(stories.count, 1)
        
        if let story = stories.first {
            XCTAssertEqual(story.author, "Test Author")
            XCTAssertEqual(story.difficultyLevel, 2)
            XCTAssertEqual(story.segments?.count, 1)
            XCTAssertEqual(story.words?.count, 1)
        }
    }
    
    // MARK: - Story Segment Tests
    
    func testStorySegmentCreation() {
        let segment = StorySegment(
            index: 0,
            arabicText: "هذا نص عربي",
            englishText: "This is Arabic text",
            transliteration: "hādhā naṣ ʿarabī"
        )
        
        XCTAssertEqual(segment.index, 0)
        XCTAssertEqual(segment.arabicText, "هذا نص عربي")
        XCTAssertEqual(segment.wordCount, 3)
    }
    
    // MARK: - Grammar Point Tests
    
    func testGrammarPointCreation() {
        let point = GrammarPoint(
            title: "The Definite Article",
            explanation: "Al- is the definite article in Arabic",
            exampleArabic: "الكتاب",
            exampleEnglish: "the book",
            ruleCategory: .sentenceStructure
        )
        
        XCTAssertEqual(point.title, "The Definite Article")
        XCTAssertEqual(point.ruleCategory, .sentenceStructure)
    }
    
    // MARK: - Achievement Tests
    
    func testAchievementUnlock() {
        let achievement = Achievement(
            title: "Test Achievement",
            description: "A test achievement",
            iconName: "star",
            category: .words,
            requirement: 10
        )
        
        XCTAssertFalse(achievement.isUnlocked)
        
        achievement.updateProgress(5)
        XCTAssertFalse(achievement.isUnlocked)
        
        achievement.updateProgress(10)
        XCTAssertTrue(achievement.isUnlocked)
        XCTAssertNotNil(achievement.unlockedDate)
    }
    
    func testAchievementProgressPercentage() {
        let achievement = Achievement(
            title: "Test",
            description: "Test",
            iconName: "star",
            category: .stories,
            requirement: 100
        )
        
        achievement.updateProgress(25)
        XCTAssertEqual(achievement.progressPercentage, 0.25)
        
        achievement.updateProgress(100)
        XCTAssertEqual(achievement.progressPercentage, 1.0)
        
        achievement.updateProgress(150)
        XCTAssertEqual(achievement.progressPercentage, 1.0) // Capped at 1.0
    }
}

// MARK: - Performance Tests

extension ArabiclyTests {
    
    func testStoryFetchingPerformance() throws {
        // Create test data
        for i in 0..<100 {
            let story = Story(
                title: "Story \(i)",
                description: "Description \(i)",
                author: "Author \(i)",
                difficultyLevel: (i % 5) + 1
            )
            context.insert(story)
        }
        try context.save()
        
        measure {
            let descriptor = FetchDescriptor<Story>()
            _ = try? context.fetch(descriptor)
        }
    }
    
    func testWordSRSCalculationPerformance() {
        let word = Word(
            arabicText: "test",
            transliteration: "test",
            englishMeaning: "test",
            partOfSpeech: .noun
        )
        
        measure {
            for _ in 0..<1000 {
                word.processReviewResponse(quality: .good)
                word.resetSRS()
            }
        }
    }
}
