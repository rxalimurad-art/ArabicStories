//
//  WordsListView.swift
//  Hikaya
//  Words list with scoring and filtering
//

import SwiftUI

struct WordsListView: View {
    @State private var viewModel = WordsListViewModel()
    @State private var showFilters = false
    @State private var selectedWord: Word?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.hikayaCream.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Stats Header
                    statsHeader
                    
                    // Search Bar
                    searchBar
                    
                    // Filter Chips
                    if showFilters {
                        filterSection
                    }
                    
                    // Words List
                    wordsList
                }
            }
            .navigationTitle("My Words")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation {
                            showFilters.toggle()
                        }
                    } label: {
                        Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.title3)
                    }
                }
            }
            .sheet(item: $selectedWord) { word in
                WordDetailView(word: word, stat: viewModel.wordStats[word.id])
            }
            .task {
                await viewModel.loadWords()
            }
        }
    }
    
    // MARK: - Stats Header
    
    private var statsHeader: some View {
        HStack(spacing: 20) {
            StatCard(
                title: "Total",
                value: "\(viewModel.totalWords)",
                icon: "book.fill",
                color: .blue
            )
            
            StatCard(
                title: "Mastered",
                value: "\(viewModel.masteredCount)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            StatCard(
                title: "Avg Score",
                value: "\(Int(viewModel.averageMastery))%",
                icon: "chart.bar.fill",
                color: .orange
            )
        }
        .padding()
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search words...", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
            
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8)
        .padding(.horizontal)
    }
    
    // MARK: - Filter Section
    
    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Sort Options
            VStack(alignment: .leading, spacing: 8) {
                Text("Sort By")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                Picker("Sort", selection: $viewModel.sortOption) {
                    ForEach(WordsListViewModel.SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                
                Button {
                    viewModel.toggleSortDirection()
                } label: {
                    Label(
                        viewModel.sortAscending ? "Ascending" : "Descending",
                        systemImage: viewModel.sortAscending ? "arrow.up" : "arrow.down"
                    )
                    .font(.caption)
                    .foregroundStyle(Color.hikayaTeal)
                }
            }
            
            // Difficulty Filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Difficulty")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { level in
                        DifficultyChip(
                            level: level,
                            isSelected: viewModel.selectedDifficulty == level
                        ) {
                            if viewModel.selectedDifficulty == level {
                                viewModel.selectedDifficulty = nil
                            } else {
                                viewModel.selectedDifficulty = level
                            }
                        }
                    }
                }
            }
            
            // Part of Speech Filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Part of Speech")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                FlowLayout(spacing: 8) {
                    ForEach(PartOfSpeech.allCases, id: \.self) { pos in
                        POSChip(
                            partOfSpeech: pos,
                            isSelected: viewModel.selectedPartOfSpeech == pos
                        ) {
                            if viewModel.selectedPartOfSpeech == pos {
                                viewModel.selectedPartOfSpeech = nil
                            } else {
                                viewModel.selectedPartOfSpeech = pos
                            }
                        }
                    }
                }
            }
            
            // Clear Filters
            Button {
                viewModel.clearFilters()
            } label: {
                Label("Clear All Filters", systemImage: "xmark")
                    .font(.subheadline)
            }
            .foregroundStyle(.red)
            .padding(.top, 8)
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 12)
        .padding(.horizontal)
    }
    
    // MARK: - Words List
    
    private var wordsList: some View {
        List {
            Section {
                ForEach(viewModel.filteredAndSortedWords) { word in
                    WordListRow(
                        word: word,
                        stat: viewModel.wordStats[word.id]
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedWord = word
                    }
                }
            } header: {
                Text("\(viewModel.filteredAndSortedWords.count) words")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.loadWords()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.filteredAndSortedWords.isEmpty {
                ContentUnavailableView(
                    "No Words Found",
                    systemImage: "textformat.abc",
                    description: Text("Try adjusting your filters")
                )
            }
        }
    }
}

// MARK: - Word List Row

struct WordListRow: View {
    let word: Word
    let stat: WordStat?
    
    var body: some View {
        HStack(spacing: 16) {
            // Arabic Word
            VStack(alignment: .leading, spacing: 4) {
                Text(word.arabicText)
                    .font(.custom("NotoNaskhArabic", size: 24))
                    .foregroundStyle(.primary)
                
                if let transliteration = word.transliteration {
                    Text(transliteration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 100, alignment: .leading)
            
            // English & Details
            VStack(alignment: .leading, spacing: 4) {
                Text(word.englishMeaning)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                
                HStack(spacing: 8) {
                    if let pos = word.partOfSpeech {
                        Text(pos.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.hikayaTeal.opacity(0.1))
                            .foregroundStyle(Color.hikayaTeal)
                            .clipShape(Capsule())
                    }
                    
                    DifficultyBadge(level: word.difficulty)
                }
            }
            
            Spacer()
            
            // Mastery Score
            if let stat = stat {
                MasteryRing(percentage: stat.masteryPercentage)
                    .frame(width: 44, height: 44)
            } else {
                MasteryRing(percentage: 0)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.5))
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }
}

struct DifficultyChip: View {
    let level: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("L\(level)")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.difficultyColor(level) : Color.gray.opacity(0.1))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct POSChip: View {
    let partOfSpeech: PartOfSpeech
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(partOfSpeech.displayName, systemImage: partOfSpeech.icon)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.hikayaTeal : Color.gray.opacity(0.1))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct DifficultyBadge: View {
    let level: Int
    
    var body: some View {
        Text("L\(level)")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.difficultyColor(level).opacity(0.15))
            .foregroundStyle(Color.difficultyColor(level))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct MasteryRing: View {
    let percentage: Int
    
    var color: Color {
        switch percentage {
        case 0..<30: return .red
        case 30..<60: return .orange
        case 60..<80: return .yellow
        case 80...100: return .green
        default: return .gray
        }
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: CGFloat(percentage) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            Text("\(percentage)%")
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
        }
    }
}

#Preview {
    WordsListView()
}
