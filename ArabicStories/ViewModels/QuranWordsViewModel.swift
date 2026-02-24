//
//  QuranWordsViewModel.swift
//  Arabicly
//  ViewModel for Quran words (quran_words collection)
//

import Foundation
import SwiftUI

@Observable
class QuranWordsViewModel {
    // Dependencies
    private let offlineDataService = OfflineDataService.shared
    
    // State
    var words: [QuranWord] = []
    var roots: [QuranRootDoc] = []
    var stats: QuranStats?
    var isLoading = false
    var error: Error?
    
    // Pagination
    var currentPage = 1
    var pageSize = 100
    var totalWords: Int {
        offlineDataService.getQuranWordsCount()
    }
    var totalPages: Int {
        let count = offlineDataService.getQuranWordsCount()
        return Int(ceil(Double(count) / Double(pageSize)))
    }
    
    // Filter & Sort
    var searchQuery: String = ""
    var selectedPOS: String?
    var selectedForm: String?
    var selectedRoot: String?
    var sortOption: SortOption = .rank
    var sortAscending: Bool = true
    
    // Available options
    let availablePOSCodes = POSCode.allCases
    let availableForms = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"]
    let availablePageSizes = [50, 100, 200, 500]
    var availableRoots: [String] = []  // Will be populated from fetched words/roots
    
    enum SortOption: String, CaseIterable {
        case rank = "Rank"
        case arabic = "Arabic"
        case occurrenceCount = "Occurrences"
        case root = "Root"
    }
    
    // MARK: - Computed Properties
    
    var filteredAndSortedWords: [QuranWord] {
        var result = words
        
        // Note: Search is now done via Firebase query (see performSearch)
        // Local filtering only for POS, Form, and Root
        
        // Apply POS filter
        if let pos = selectedPOS {
            result = result.filter { $0.morphology.partOfSpeech == pos }
        }
        
        // Apply Form filter
        if let form = selectedForm {
            result = result.filter { $0.morphology.form == form }
        }
        
        // Apply Root filter
        if let root = selectedRoot, !root.isEmpty {
            result = result.filter { $0.root?.arabic == root }
        }
        
        return result
    }
    
    // MARK: - Search
    func performSearch(query: String) async {
        guard !query.isEmpty else {
            // Reset to normal pagination when search is cleared
            currentPage = 1
            await loadWords()
            return
        }
        
        isLoading = true
        error = nil
        
        // Search from offline bundle
        let results = offlineDataService.searchQuranWords(query: query)
        
        await MainActor.run {
            self.words = results
            self.isLoading = false
        }
    }
    
    var totalOccurrences: Int {
        words.reduce(0) { $0 + $1.occurrenceCount }
    }
    
    // MARK: - Data Loading
    
    func loadWords() async {
        isLoading = true
        error = nil
        
        // Load all words from offline bundle
        var allWords = offlineDataService.loadQuranWords()
        
        // Apply local sorting
        switch sortOption {
        case .rank:
            allWords.sort { $0.rank < $1.rank }
        case .arabic:
            allWords.sort { $0.arabicText < $1.arabicText }
        case .occurrenceCount:
            allWords.sort { $0.occurrenceCount > $1.occurrenceCount }
        case .root:
            allWords.sort { ($0.root?.arabic ?? "") < ($1.root?.arabic ?? "") }
        }
        
        // Apply POS filter locally
        if let pos = selectedPOS {
            allWords = allWords.filter { $0.morphology.partOfSpeech == pos }
        }
        
        // Apply Form filter locally
        if let form = selectedForm {
            allWords = allWords.filter { $0.morphology.form == form }
        }
        
        // Apply pagination
        let startIndex = (currentPage - 1) * pageSize
        let endIndex = min(startIndex + pageSize, allWords.count)
        let paginatedWords = startIndex < allWords.count ? Array(allWords[startIndex..<endIndex]) : []
        
        await MainActor.run {
            self.words = paginatedWords
            self.isLoading = false
            
            // Extract unique roots from all words for filtering
            if self.availableRoots.isEmpty {
                self.availableRoots = offlineDataService.getUniqueRoots()
            }
        }
    }
    
    func loadRoots() async {
        isLoading = true
        error = nil
        
        // Get all unique roots from offline bundle
        let allRoots = offlineDataService.getUniqueRoots()
        
        // Create QuranRootDoc objects from unique roots
        let rootDocs = allRoots.map { root -> QuranRootDoc in
            let wordsWithRoot = offlineDataService.getQuranWordsByRoot(root: root)
            let totalOccurrences = wordsWithRoot.reduce(0) { $0 + $1.occurrenceCount }
            
            return QuranRootDoc(
                id: root,
                root: root,
                transliteration: root, // Could add transliteration mapping
                derivativeCount: wordsWithRoot.count,
                totalOccurrences: totalOccurrences,
                sampleDerivatives: wordsWithRoot.prefix(3).map { $0.arabicText }
            )
        }
        
        // Sort based on sortOption
        var sortedRoots = rootDocs
        switch sortOption {
        case .occurrenceCount:
            sortedRoots.sort { $0.totalOccurrences > $1.totalOccurrences }
        case .root:
            sortedRoots.sort { $0.root < $1.root }
        default:
            sortedRoots.sort { $0.totalOccurrences > $1.totalOccurrences }
        }
        
        await MainActor.run {
            self.roots = sortedRoots
            self.availableRoots = allRoots
            self.isLoading = false
        }
    }
    
    func loadStats() async {
        // Get stats from offline data
        let offlineStats = offlineDataService.getQuranStats()
        await MainActor.run {
            self.stats = offlineStats
        }
    }
    
    func searchWords(query: String) async {
        guard !query.isEmpty else {
            await loadWords()
            return
        }
        
        isLoading = true
        error = nil
        
        // Search from offline bundle
        let results = offlineDataService.searchQuranWords(query: query)
        await MainActor.run {
            self.words = results
            self.isLoading = false
        }
    }
    
    func fetchWordsByRoot(root: String) async {
        isLoading = true
        error = nil
        
        // Load words by root from offline bundle
        let results = offlineDataService.getQuranWordsByRoot(root: root)
        await MainActor.run {
            self.words = results
            self.isLoading = false
        }
    }
    
    // MARK: - Pagination Actions
    
    func goToPage(_ page: Int) async {
        guard page >= 1 && page <= totalPages else { return }
        currentPage = page
        await loadWords()
    }
    
    func nextPage() async {
        guard currentPage < totalPages else { return }
        currentPage += 1
        await loadWords()
    }
    
    func previousPage() async {
        guard currentPage > 1 else { return }
        currentPage -= 1
        await loadWords()
    }
    
    func firstPage() async {
        await goToPage(1)
    }
    
    func lastPage() async {
        await goToPage(totalPages)
    }
    
    func setPageSize(_ size: Int) async {
        pageSize = size
        currentPage = 1
        await loadWords()
    }
    
    // MARK: - Filter Actions
    
    func clearFilters() {
        searchQuery = ""
        selectedPOS = nil
        selectedForm = nil
        selectedRoot = nil
        sortOption = .rank
        sortAscending = true
        currentPage = 1
    }
    
    func toggleSortDirection() {
        sortAscending.toggle()
    }
    
    func filterByPOS(_ pos: String?) {
        selectedPOS = pos
        currentPage = 1
    }
    
    func filterByForm(_ form: String?) {
        selectedForm = form
        currentPage = 1
    }
}
