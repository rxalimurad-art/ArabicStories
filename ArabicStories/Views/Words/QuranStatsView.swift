//
//  QuranStatsView.swift
//  Arabicly
//  Statistics view for Quran data
//

import SwiftUI

struct QuranStatsView: View {
    let stats: QuranStats
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Main Stats Grid
                    mainStatsGrid
                    
                    // Coverage Stats
                    coverageSection
                    
                    // Metadata
                    metadataSection
                }
                .padding()
            }
            .navigationTitle("📊 Quran Statistics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Main Stats Grid
    private var mainStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            QuranStatCard(
                value: stats.totalUniqueWords.formatted(),
                label: "Unique Words",
                icon: "textformat",
                color: .blue
            )
            QuranStatCard(
                value: stats.totalTokens.formatted(),
                label: "Total Tokens",
                icon: "number",
                color: .green
            )
            QuranStatCard(
                value: stats.uniqueRoots.formatted(),
                label: "Unique Roots",
                icon: "arrow.branch",
                color: .purple
            )
            QuranStatCard(
                value: stats.uniqueRootForms.formatted(),
                label: "Root Forms",
                icon: "doc.text",
                color: .orange
            )
        }
    }
    
    // MARK: - Coverage Section
    private var coverageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Data Coverage")
                .font(.headline)
            
            VStack(spacing: 12) {
                QuranCoverageBar(
                    label: "Words with Roots",
                    count: stats.wordsWithRoots,
                    total: stats.totalUniqueWords,
                    color: .purple
                )
                QuranCoverageBar(
                    label: "Words with POS",
                    count: stats.wordsWithPOS,
                    total: stats.totalUniqueWords,
                    color: .blue
                )
                QuranCoverageBar(
                    label: "Words with Lemmas",
                    count: stats.wordsWithLemmas,
                    total: stats.totalUniqueWords,
                    color: .green
                )
                QuranCoverageBar(
                    label: "Words with Meanings",
                    count: stats.wordsWithMeanings,
                    total: stats.totalUniqueWords,
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Metadata Section
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metadata")
                .font(.headline)
            
            if let version = stats.version {
                HStack {
                    Text("Version")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(version)
                        .fontWeight(.medium)
                }
            }
            
            if let generatedAt = stats.generatedAt {
                HStack {
                    Text("Generated")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(generatedAt)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Stat Card
struct QuranStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Coverage Bar
struct QuranCoverageBar: View {
    let label: String
    let count: Int
    let total: Int
    let color: Color
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(percentage * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * percentage)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            Text("\(count.formatted()) / \(total.formatted())")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview
#Preview {
    QuranStatsView(stats: QuranStats(
        totalUniqueWords: 18994,
        totalTokens: 77430,
        uniqueRoots: 1651,
        uniqueRootForms: 15142,
        wordsWithRoots: 17864,
        wordsWithPOS: 18993,
        wordsWithLemmas: 18962,
        wordsWithMeanings: 18994,
        generatedAt: "2026-02-14",
        version: "1.0"
    ))
}
