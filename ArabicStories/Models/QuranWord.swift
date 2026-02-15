//
//  QuranWord.swift
//  Arabicly
//  Quran Word model - matches quran_words Firestore collection
//

import Foundation

// MARK: - Quran Word (matches quran_words collection)
struct QuranWord: Identifiable, Codable, Hashable {
    var id: String
    var rank: Int
    var arabicText: String
    var arabicWithoutDiacritics: String
    var buckwalter: String?
    var englishMeaning: String
    var root: QuranRoot?
    var morphology: QuranMorphology
    var occurrenceCount: Int
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case id
        case rank
        case arabicText
        case arabicWithoutDiacritics
        case buckwalter
        case englishMeaning
        case root
        case morphology
        case occurrenceCount
    }
    
    // MARK: - Computed Properties
    var displayArabic: String {
        arabicText
    }
    
    var displayTransliteration: String {
        buckwalter ?? ""
    }
}

// MARK: - Quran Root (nested in quran_words, also in quran_roots collection)
struct QuranRoot: Codable, Hashable {
    var arabic: String?
    var transliteration: String?
}

// MARK: - Quran Morphology (nested in quran_words)
struct QuranMorphology: Codable, Hashable {
    var partOfSpeech: String?        // N, V, P, PN, ADJ, ADV, etc.
    var posDescription: String?      // "فعل", "اسم", "حرف جر"
    var lemma: String?               // Dictionary form
    var form: String?                // Verb form (1-10)
    var tense: String?               // Perfect, Imperfect, Imperative
    var gender: String?              // Masculine, Feminine
    var number: String?              // Singular, Dual, Plural
    var grammaticalCase: String?     // Nominative, Accusative, Genitive
    var passive: Bool                // Passive voice marker
    var breakdown: String?           // Full morphological breakdown
}

// MARK: - Quran Stats (quran_stats collection)
struct QuranStats: Codable {
    var totalUniqueWords: Int
    var totalTokens: Int
    var uniqueRoots: Int
    var uniqueRootForms: Int
    var wordsWithRoots: Int
    var wordsWithPOS: Int
    var wordsWithLemmas: Int
    var wordsWithMeanings: Int
    var generatedAt: String?
    var version: String?
}

// MARK: - Quran Root Document (quran_roots collection)
struct QuranRootDoc: Identifiable, Codable, Hashable {
    var id: String
    var root: String
    var transliteration: String
    var derivativeCount: Int
    var totalOccurrences: Int
    var sampleDerivatives: [String]
}

// MARK: - POS Code Helper
enum POSCode: String, CaseIterable {
    case noun = "N"
    case verb = "V"
    case preposition = "P"
    case properNoun = "PN"
    case adjective = "ADJ"
    case adverb = "ADV"
    case pronoun = "PRO"
    case conjunction = "CONJ"
    case negative = "NEG"
    case conditional = "COND"
    case relative = "REL"
    case demonstrative = "DEM"
    case time = "T"
    case location = "LOC"
    case interrogative = "INTG"
    case vocative = "VOC"
    case certainty = "CERT"
    case emphatic = "EMPH"
    case exhortation = "EXH"
    case exclamation = "EXL"
    case imperative = "IMPV"
    case purpose = "PRP"
    case resumption = "REM"
    case restriction = "RES"
    case result = "RSLT"
    case supplemental = "SUP"
    case amendment = "AMD"
    case answer = "ANS"
    case aversion = "AVR"
    case causative = "CAUS"
    case comitative = "COM"
    case equalization = "EQ"
    case exceptive = "EXP"
    case future = "FUT"
    case incitement = "INC"
    case retraction = "RET"
    case subordinating = "SUB"
    case surprise = "SUR"
    
    var displayName: String {
        switch self {
        case .noun: return "Noun (اسم)"
        case .verb: return "Verb (فعل)"
        case .preposition: return "Preposition (حرف جر)"
        case .properNoun: return "Proper Noun (اسم علم)"
        case .adjective: return "Adjective (صفة)"
        case .adverb: return "Adverb (ظرف)"
        case .pronoun: return "Pronoun (ضمير)"
        case .conjunction: return "Conjunction (حرف عطف)"
        case .negative: return "Negative"
        case .conditional: return "Conditional"
        case .relative: return "Relative Pronoun"
        case .demonstrative: return "Demonstrative"
        case .time: return "Time Adverb"
        case .location: return "Location Adverb"
        case .interrogative: return "Interrogative"
        case .vocative: return "Vocative"
        case .certainty: return "Certainty"
        case .emphatic: return "Emphatic"
        case .exhortation: return "Exhortation"
        case .exclamation: return "Exclamation"
        case .imperative: return "Imperative"
        case .purpose: return "Purpose"
        case .resumption: return "Resumption"
        case .restriction: return "Restriction"
        case .result: return "Result"
        case .supplemental: return "Supplemental"
        case .amendment: return "Amendment"
        case .answer: return "Answer"
        case .aversion: return "Aversion"
        case .causative: return "Causative"
        case .comitative: return "Comitative"
        case .equalization: return "Equalization"
        case .exceptive: return "Exceptive"
        case .future: return "Future"
        case .incitement: return "Incitement"
        case .retraction: return "Retraction"
        case .subordinating: return "Subordinating"
        case .surprise: return "Surprise"
        }
    }
    
    var icon: String {
        switch self {
        case .noun: return "textformat"
        case .verb: return "bolt.fill"
        case .preposition: return "arrow.right"
        case .properNoun: return "person.fill"
        case .adjective: return "paintbrush"
        case .adverb: return "speedometer"
        case .pronoun: return "person"
        case .conjunction: return "link"
        default: return "text.quote"
        }
    }
}

// MARK: - Helper Extensions
extension QuranWord {
    /// Get POS display name
    var posDisplayName: String {
        guard let pos = morphology.partOfSpeech,
              let code = POSCode(rawValue: pos) else {
            return morphology.partOfSpeech ?? "Unknown"
        }
        return code.displayName
    }
    
    /// Get POS icon
    var posIcon: String {
        guard let pos = morphology.partOfSpeech,
              let code = POSCode(rawValue: pos) else {
            return "text.quote"
        }
        return code.icon
    }
    
    /// Check if this is a verb
    var isVerb: Bool {
        morphology.partOfSpeech == "V"
    }
    
    /// Check if this is a noun
    var isNoun: Bool {
        morphology.partOfSpeech == "N"
    }
    
    /// Get form display (e.g., "Form I", "Form II")
    var formDisplay: String? {
        guard let form = morphology.form else { return nil }
        let formNumbers = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]
        if let num = Int(form), num >= 1 && num <= 12 {
            return "Form \(formNumbers[num - 1])"
        }
        return "Form \(form)"
    }
}
