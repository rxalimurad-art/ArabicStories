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
    private let firebaseService = FirebaseService.shared
    
    // State
    var words: [QuranWord] = []
    var roots: [QuranRootDoc] = []
    var stats: QuranStats?
    var isLoading = false
    var error: Error?
    
    // Pagination
    var currentPage = 1
    var pageSize = 100
    var totalWords = 18994
    var totalPages: Int {
        Int(ceil(Double(totalWords) / Double(pageSize)))
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
        
        do {
            // Search from all words in Firebase
            let results = try await firebaseService.searchQuranWords(query: query, limit: 100)
            
            await MainActor.run {
                self.words = results
                self.totalWords = results.count
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    var totalOccurrences: Int {
        words.reduce(0) { $0 + $1.occurrenceCount }
    }
    
    // MARK: - Data Loading
    
    func loadWords() async {
        isLoading = true
        error = nil
        
        do {
            let sortField = sortOption == .rank ? "rank" : 
                           sortOption == .occurrenceCount ? "occurrenceCount" : 
                           sortOption == .arabic ? "arabicText" : "rank"
            
            let (fetchedWords, total) = try await firebaseService.fetchQuranWords(
                limit: pageSize,
                offset: (currentPage - 1) * pageSize,
                sort: sortField,
                pos: selectedPOS,
                form: selectedForm
            )
            
            await MainActor.run {
                self.words = fetchedWords
                self.totalWords = total
                self.isLoading = false
                
                // Extract unique roots from fetched words for filtering
                let rootsFromWords = Set(fetchedWords.compactMap { $0.root?.arabic })
                if self.availableRoots.isEmpty {
                    self.availableRoots = Array(rootsFromWords).sorted()
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    func loadRoots() async {
        isLoading = true
        error = nil
        
        do {
            let sortField = sortOption == .occurrenceCount ? "totalOccurrences" :
                           sortOption == .rank ? "derivativeCount" : "totalOccurrences"
            
            let (fetchedRoots, total) = try await firebaseService.fetchQuranRoots(
                limit: 200,  // Load more roots for the filter
                offset: 0,
                sort: sortField
            )
            
            await MainActor.run {
                self.roots = fetchedRoots
                // Extract unique root strings for the filter
                self.availableRoots = fetchedRoots.compactMap { $0.root }.sorted()
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    func loadStats() async {
        do {
            let fetchedStats = try await firebaseService.fetchQuranStats()
            await MainActor.run {
                self.stats = fetchedStats
            }
        } catch {
            print("❌ Error loading Quran stats: \(error)")
        }
    }
    
    func searchWords(query: String) async {
        guard !query.isEmpty else {
            await loadWords()
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            let results = try await firebaseService.searchQuranWords(query: query, limit: 100)
            await MainActor.run {
                self.words = results
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    func fetchWordsByRoot(root: String) async {
        isLoading = true
        error = nil
        
        do {
            let results = try await firebaseService.fetchWordsByRoot(root: root, limit: 500)
            await MainActor.run {
                self.words = results
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
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
