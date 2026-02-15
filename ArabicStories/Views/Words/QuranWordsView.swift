//
//  QuranWordsView.swift
//  Arabicly
//  View for browsing Quran words (quran_words collection)
//

import SwiftUI

struct QuranWordsView: View {
    @State private var viewModel = QuranWordsViewModel()
    @State private var showingStats = false
    @State private var selectedWord: QuranWord?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats Bar
                if let stats = viewModel.stats {
                    statsBar(stats: stats)
                }
                
                // Filters
                filterBar
                
                // Count Display
                countDisplay
                
                // Words Grid
                wordsGrid
                
                // Pagination (hidden when searching)
                if viewModel.searchQuery.isEmpty {
                    paginationBar
                }
            }
            .navigationTitle("📖 Quran Words")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingStats = true }) {
                        Image(systemName: "chart.bar")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            .sheet(item: $selectedWord) { word in
                QuranWordDetailView(word: word)
            }
            .sheet(isPresented: $showingStats) {
                if let stats = viewModel.stats {
                    QuranStatsView(stats: stats)
                }
            }
            .task {
                await viewModel.loadWords()
                await viewModel.loadStats()
            }
        }
    }
    
    // MARK: - Stats Bar
    private func statsBar(stats: QuranStats) -> some View {
        HStack(spacing: 12) {
            StatItemCompact(value: stats.totalUniqueWords.formatted(), label: "Unique Words", color: .blue)
            Divider().frame(height: 30)
            StatItemCompact(value: stats.totalTokens.formatted(), label: "Total Occurrences in Quran", color: .orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }
    
    // MARK: - Filter Bar
    private var filterBar: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 17))
                
                TextField("Search all words...", text: $viewModel.searchQuery)
                    .font(.body)
                    .onSubmit {
                        Task {
                            await viewModel.performSearch(query: viewModel.searchQuery)
                        }
                    }
                
                if !viewModel.searchQuery.isEmpty {
                    Button(action: { 
                        viewModel.searchQuery = ""
                        Task {
                            await viewModel.performSearch(query: "")
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 20))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Quick Filters (horizontal scrollable chips)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Sort Button
                    Menu {
                        ForEach(QuranWordsViewModel.SortOption.allCases, id: \.self) { option in
                            Button(option.rawValue) {
                                viewModel.sortOption = option
                                Task {
                                    await viewModel.loadWords()
                                }
                            }
                        }
                    } label: {
                        WordFilterChip(
                            icon: "arrow.up.arrow.down",
                            label: viewModel.sortOption.rawValue,
                            isActive: viewModel.sortOption != .rank
                        )
                    }
                    
                    // POS Filter
                    Menu {
                        Button("All") {
                            viewModel.selectedPOS = nil
                            viewModel.selectedForm = nil
                            Task {
                                await viewModel.loadWords()
                            }
                        }
                        ForEach(viewModel.availablePOSCodes.prefix(8), id: \.rawValue) { pos in
                            Button(pos.displayName) {
                                viewModel.selectedPOS = pos.rawValue
                                Task {
                                    await viewModel.loadWords()
                                }
                            }
                        }
                    } label: {
                        WordFilterChip(
                            icon: "textformat",
                            label: viewModel.selectedPOS ?? "POS",
                            isActive: viewModel.selectedPOS != nil
                        )
                    }
                    
                    // Form Filter (only show if POS is V - verb)
                    if viewModel.selectedPOS == "V" {
                        Menu {
                            Button("All Forms") {
                                viewModel.selectedForm = nil
                                Task {
                                    await viewModel.loadWords()
                                }
                            }
                            ForEach(viewModel.availableForms, id: \.self) { form in
                                Button("Form \(form)") {
                                    viewModel.selectedForm = form
                                    Task {
                                        await viewModel.loadWords()
                                    }
                                }
                            }
                        } label: {
                            WordFilterChip(
                                icon: "number",
                                label: viewModel.selectedForm != nil ? "Form \(viewModel.selectedForm!)" : "Form",
                                isActive: viewModel.selectedForm != nil
                            )
                        }
                    }
                    
                    // Clear Filters (only show if any filter is active)
                    if viewModel.selectedPOS != nil || viewModel.selectedForm != nil || !viewModel.searchQuery.isEmpty {
                        Button(action: {
                            viewModel.clearFilters()
                            Task {
                                await viewModel.loadWords()
                            }
                        }) {
                            WordFilterChip(
                                icon: "xmark",
                                label: "Clear",
                                isActive: true,
                                activeColor: .red
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Count Display
    private var countDisplay: some View {
        HStack(spacing: 8) {
            if viewModel.searchQuery.isEmpty {
                // Normal browsing mode
                Text("\(viewModel.totalWords.formatted()) unique words")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text("Page \(viewModel.currentPage) of \(viewModel.totalPages)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                // Search results mode
                Text("\(viewModel.words.count) results found")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    // MARK: - Words Grid
    private var wordsGrid: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView("Loading Quran words...")
                    .padding()
            } else if viewModel.filteredAndSortedWords.isEmpty {
                ContentUnavailableView(
                    "No Words Found",
                    systemImage: "text.book.closed",
                    description: Text("Try adjusting your filters or search query")
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                    ForEach(viewModel.filteredAndSortedWords) { word in
                        QuranWordCard(word: word)
                            .onTapGesture {
                                selectedWord = word
                            }
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Pagination Bar
    private var paginationBar: some View {
        HStack(spacing: 12) {
            // First Page
            Button(action: { Task { await viewModel.firstPage() } }) {
                Image(systemName: "chevron.backward.2")
                    .font(.system(size: 14, weight: .semibold))
            }
            .disabled(viewModel.currentPage == 1 || viewModel.isLoading)
            .frame(width: 36, height: 36)
            .background(Color(.systemGray5))
            .cornerRadius(8)
            
            // Previous Page
            Button(action: { Task { await viewModel.previousPage() } }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
            }
            .disabled(viewModel.currentPage == 1 || viewModel.isLoading)
            .frame(width: 36, height: 36)
            .background(Color(.systemGray5))
            .cornerRadius(8)
            
            // Page Input
            HStack(spacing: 4) {
                TextField("", value: $viewModel.currentPage, formatter: NumberFormatter())
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 40)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .font(.system(size: 16, weight: .medium))
                    .onSubmit {
                        Task { await viewModel.loadWords() }
                    }
                
                Text("/ \(viewModel.totalPages)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // Next Page
            Button(action: { Task { await viewModel.nextPage() } }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .disabled(viewModel.currentPage >= viewModel.totalPages || viewModel.isLoading)
            .frame(width: 36, height: 36)
            .background(Color(.systemGray5))
            .cornerRadius(8)
            
            // Last Page
            Button(action: { Task { await viewModel.lastPage() } }) {
                Image(systemName: "chevron.forward.2")
                    .font(.system(size: 14, weight: .semibold))
            }
            .disabled(viewModel.currentPage >= viewModel.totalPages || viewModel.isLoading)
            .frame(width: 36, height: 36)
            .background(Color(.systemGray5))
            .cornerRadius(8)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    // MARK: - Refresh Button
    private var refreshButton: some View {
        Button(action: { Task { 
            await viewModel.loadWords()
            await viewModel.loadStats()
        } }) {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(viewModel.isLoading)
    }
}

// MARK: - Quran Word Card
struct QuranWordCard: View {
    let word: QuranWord
    
    var body: some View {
        VStack(spacing: 10) {
            // Rank and Occurrence
            HStack {
                Text("#\(word.rank)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                if word.occurrenceCount > 0 {
                    Text("\(word.occurrenceCount)×")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                }
            }
            
            // Arabic text (main focus)
            Text(word.arabicText)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .frame(height: 40)
            
            // English meaning
            Text(word.englishMeaning)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 36)
            
            // Buckwalter
            if let buckwalter = word.buckwalter {
                Text(buckwalter)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            // Tags row
            HStack(spacing: 6) {
                if let pos = word.morphology.partOfSpeech {
                    Text(pos)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                }
                
                if let root = word.root?.arabic {
                    Text(root)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.purple.opacity(0.12))
                        .foregroundColor(.purple)
                        .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(height: 170)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 2)
    }
}

// MARK: - Tag View
struct TagView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

// MARK: - Word Filter Chip
struct WordFilterChip: View {
    let icon: String
    let label: String
    let isActive: Bool
    var activeColor: Color = .teal
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(label)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isActive ? activeColor.opacity(0.15) : Color(.systemGray5))
        .foregroundColor(isActive ? activeColor : .gray)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isActive ? activeColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Stat Item Compact
struct StatItemCompact: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Stat Badge
struct QuranWordStatBadge: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview
#Preview {
    QuranWordsView()
}
