//
//  ArabicTextUtils.swift
//  Arabicly
//  Arabic text normalization and utilities
//

import Foundation

enum ArabicTextUtils {
    
    // MARK: - Diacritics (Tashkeel)
    
    /// All Arabic diacritic marks (combining characters)
    private static let diacritics: Set<Character> = [
        "\u{064B}", // FATHATAN
        "\u{064C}", // DAMMATAN
        "\u{064D}", // KASRATAN
        "\u{064E}", // FATHA
        "\u{064F}", // DAMMA
        "\u{0650}", // KASRA
        "\u{0651}", // SHADDA
        "\u{0652}", // SUKUN
        "\u{0653}", // MADDAH
        "\u{0654}", // HAMZA ABOVE
        "\u{0655}", // HAMZA BELOW
        "\u{0670}", // SUPERSCRIPT ALEF
    ]
    
    /// Remove all diacritics from Arabic text
    static func stripDiacritics(_ text: String) -> String {
        return text.filter { !diacritics.contains($0) }
    }
    
    /// Check if character is a diacritic
    static func isDiacritic(_ char: Character) -> Bool {
        return diacritics.contains(char)
    }
    
    // MARK: - Letter Normalization
    
    /// Normalize Arabic letter variants to standard forms
    static func normalizeLetters(_ text: String) -> String {
        var result = text
        
        // Alef variants -> standard Alef (ا)
        result = result.replacingOccurrences(of: "أ", with: "ا")
        result = result.replacingOccurrences(of: "إ", with: "ا")
        result = result.replacingOccurrences(of: "آ", with: "ا")
        result = result.replacingOccurrences(of: "ٱ", with: "ا")
        
        // Taa marbuta (ة) -> Ha (ه) for matching
        // Note: Keep as-is for display, only use for matching
        result = result.replacingOccurrences(of: "ة", with: "ه")
        
        // Yaa variants
        result = result.replacingOccurrences(of: "ى", with: "ي")
        
        // Kaf variants
        result = result.replacingOccurrences(of: "ڪ", with: "ك")
        
        return result
    }
    
    // MARK: - Punctuation and Special Characters
    
    /// Arabic punctuation marks
    private static let arabicPunctuation: Set<Character> = [
        "،", // Arabic comma
        "؛", // Arabic semicolon
        "؟", // Arabic question mark
        "٪", // Arabic percent
        "٫", // Arabic decimal separator
        "٬", // Arabic thousands separator
    ]
    
    /// All punctuation to strip
    private static let allPunctuation: CharacterSet = {
        var set = CharacterSet.punctuationCharacters
        set.insert(charactersIn: String(arabicPunctuation))
        return set
    }()
    
    /// Remove punctuation and whitespace
    static func stripPunctuation(_ text: String) -> String {
        return text.trimmingCharacters(in: allPunctuation.union(.whitespacesAndNewlines))
    }
    
    /// Remove kashida/tatweel (ـ)
    static func stripKashida(_ text: String) -> String {
        return text.replacingOccurrences(of: "ـ", with: "")
    }
    
    // MARK: - Combined Normalization
    
    /// Full normalization for text matching/searching
    /// Strips diacritics, normalizes letters, removes kashida and punctuation
    static func normalizeForMatching(_ text: String) -> String {
        var result = text
        result = stripDiacritics(result)
        result = normalizeLetters(result)
        result = stripKashida(result)
        result = stripPunctuation(result)
        return result
    }
    
    /// Light normalization - keeps letters intact, just removes diacritics and punctuation
    static func lightNormalize(_ text: String) -> String {
        var result = text
        result = stripDiacritics(result)
        result = stripPunctuation(result)
        return result
    }
    
    // MARK: - Word Matching
    
    /// Check if two Arabic words match (with normalization)
    static func wordsMatch(_ word1: String, _ word2: String) -> Bool {
        let normalized1 = normalizeForMatching(word1)
        let normalized2 = normalizeForMatching(word2)
        
        // Exact match
        if normalized1 == normalized2 {
            return true
        }
        
        // One contains the other (for partial matches)
        if normalized1.contains(normalized2) || normalized2.contains(normalized1) {
            return true
        }
        
        return false
    }
    
    /// Check if text contains word (with normalization)
    static func containsWord(_ text: String, word: String) -> Bool {
        let normalizedText = normalizeForMatching(text)
        let normalizedWord = normalizeForMatching(word)
        return normalizedText.contains(normalizedWord)
    }
    
    // MARK: - Display Helpers
    
    /// Check if character is Arabic
    static func isArabicCharacter(_ char: Character) -> Bool {
        guard let scalar = char.unicodeScalars.first else { return false }
        // Arabic Unicode block: 0600-06FF
        // Arabic Supplement: 0750-077F
        // Arabic Extended-A: 08A0-08FF
        // Arabic Presentation Forms-A: FB50-FDFF
        // Arabic Presentation Forms-B: FE70-FEFF
        let value = scalar.value
        return (value >= 0x0600 && value <= 0x06FF) ||
               (value >= 0x0750 && value <= 0x077F) ||
               (value >= 0x08A0 && value <= 0x08FF) ||
               (value >= 0xFB50 && value <= 0xFDFF) ||
               (value >= 0xFE70 && value <= 0xFEFF)
    }
    
    /// Check if text contains any Arabic characters
    static func containsArabic(_ text: String) -> Bool {
        return text.contains { isArabicCharacter($0) }
    }
    
    /// Get word count (handles Arabic spacing properly)
    static func wordCount(_ text: String) -> Int {
        return text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
}
