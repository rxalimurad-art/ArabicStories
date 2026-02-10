//
//  CreateStoryView.swift
//  Hikaya
//  Create and edit stories with rich text input
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct CreateStoryView: View {
    @Bindable var viewModel = CreateStoryViewModel()
    @State private var showingImagePicker = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.hikayaBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Step Indicator
                    StepIndicator(currentStep: viewModel.currentStep)
                        .padding()
                    
                    // Content based on step
                    ScrollView {
                        switch viewModel.currentStep {
                        case .content:
                            StoryContentForm(viewModel: viewModel)
                        case .vocabulary:
                            VocabularyForm(viewModel: viewModel)
                        case .preview:
                            StoryPreview(viewModel: viewModel)
                        }
                    }
                    
                    // Navigation Buttons
                    StepNavigation(viewModel: viewModel)
                        .padding()
                }
            }
            .navigationTitle("Create Story")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingImagePicker) {
                // Image picker would go here
            }
            .alert("Success", isPresented: $viewModel.showSuccessAlert) {
                Button("OK") {
                    viewModel.reset()
                }
            } message: {
                Text("Your story has been saved successfully!")
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Step Indicator

struct StepIndicator: View {
    let currentStep: CreationStep
    
    private let steps = CreationStep.allCases
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element) { index, step in
                StepItem(
                    step: step,
                    isActive: step == currentStep,
                    isCompleted: index < steps.firstIndex(of: currentStep)!
                )
                
                if index < steps.count - 1 {
                    StepConnector(isActive: index < steps.firstIndex(of: currentStep)!)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Step Item

struct StepItem: View {
    let step: CreationStep
    let isActive: Bool
    let isCompleted: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 40, height: 40)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: step.icon)
                        .font(.callout)
                        .foregroundStyle(isActive ? .white : .secondary)
                }
            }
            
            Text(step.rawValue)
                .font(.caption.weight(isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? .primary : .secondary)
        }
    }
    
    private var backgroundColor: Color {
        if isActive || isCompleted {
            return .hikayaTeal
        }
        return Color(.systemGray5)
    }
}

// MARK: - Step Connector

struct StepConnector: View {
    let isActive: Bool
    
    var body: some View {
        Rectangle()
            .fill(isActive ? Color.hikayaTeal : Color(.systemGray4))
            .frame(height: 2)
            .padding(.horizontal, 4)
    }
}

// MARK: - Story Content Form

struct StoryContentForm: View {
    @Bindable var viewModel: CreateStoryViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Basic Info Section
            FormSection(title: "Basic Information") {
                VStack(spacing: 16) {
                    CustomTextField(
                        title: "Story Title (English)",
                        text: $viewModel.title,
                        placeholder: "Enter story title"
                    )
                    
                    CustomTextField(
                        title: "العنوان بالعربية",
                        text: $viewModel.titleArabic,
                        placeholder: "أدخل العنوان",
                        isRTL: true
                    )
                    
                    CustomTextField(
                        title: "Author",
                        text: $viewModel.author,
                        placeholder: "Enter author name"
                    )
                    
                    // Difficulty Level
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Difficulty Level")
                            .font(.subheadline.weight(.medium))
                        
                        DifficultySelector(selectedLevel: $viewModel.difficultyLevel)
                    }
                    
                    // Category
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.subheadline.weight(.medium))
                        
                        Picker("Category", selection: $viewModel.category) {
                            ForEach(StoryCategory.allCases, id: \.self) { category in
                                HStack {
                                    Image(systemName: category.icon)
                                    Text(category.displayName)
                                }
                                .tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
            
            // Description Section
            FormSection(title: "Description") {
                VStack(spacing: 12) {
                    CustomTextEditor(
                        title: "Description (English)",
                        text: $viewModel.description,
                        placeholder: "Enter a brief description of the story...",
                        height: 80
                    )
                    
                    CustomTextEditor(
                        title: "الوصف بالعربية",
                        text: $viewModel.descriptionArabic,
                        placeholder: "أدخل وصفاً مختصراً للقصة...",
                        height: 80,
                        isRTL: true
                    )
                }
            }
            
            // Cover Image
            FormSection(title: "Cover Image") {
                CoverImagePicker(viewModel: viewModel)
            }
            
            // Segments
            FormSection(title: "Story Content") {
                VStack(spacing: 12) {
                    ForEach($viewModel.segments) { $segment in
                        SegmentEditor(segment: $segment, onDelete: {
                            if let index = viewModel.segments.firstIndex(where: { $0.id == segment.id }) {
                                viewModel.removeSegment(at: index)
                            }
                        })
                    }
                    
                    Button {
                        viewModel.addSegment()
                    } label: {
                        Label("Add Segment", systemImage: "plus.circle")
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.hikayaTeal.opacity(0.1))
                    .foregroundStyle(Color.hikayaTeal)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
    }
}

// MARK: - Form Section

struct FormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
            
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Custom Text Field

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var isRTL: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
            
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        }
    }
}

// MARK: - Custom Text Editor

struct CustomTextEditor: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let height: CGFloat
    var isRTL: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .frame(height: height)
                    .padding(4)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

// MARK: - Difficulty Selector

struct DifficultySelector: View {
    @Binding var selectedLevel: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { level in
                Button {
                    selectedLevel = level
                } label: {
                    Text("L\(level)")
                        .font(.subheadline.weight(selectedLevel == level ? .bold : .regular))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedLevel == level ? difficultyColor(for: level) : Color(.systemGray5))
                        .foregroundStyle(selectedLevel == level ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func difficultyColor(for level: Int) -> Color {
        switch level {
        case 1: return .green
        case 2: return .hikayaTeal
        case 3: return .blue
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }
}

// MARK: - Cover Image Picker

struct CoverImagePicker: View {
    @Bindable var viewModel: CreateStoryViewModel
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        VStack {
            if let imageData = viewModel.coverImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.hikayaTeal)
                        
                        Text("Tap to select cover image")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .background(Color.hikayaTeal.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                viewModel.selectedCoverImage = newItem
                await viewModel.loadSelectedImage()
            }
        }
    }
}

// MARK: - Segment Editor

struct SegmentEditor: View {
    @Binding var segment: CreateStoryViewModel.StorySegmentDraft
    let onDelete: () -> Void
    @State private var isExpanded = true
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Segment \(segment.index + 1)")
                    .font(.subheadline.weight(.semibold))
                
                Spacer()
                
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
            
            if isExpanded {
                VStack(spacing: 12) {
                    // Arabic Text
                    TextEditor(text: $segment.arabicText)
                        .frame(height: 80)
                        .padding(4)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .environment(\.layoutDirection, .rightToLeft)
                    
                    // Transliteration
                    TextField("Transliteration (optional)", text: $segment.transliteration)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    // English Text
                    TextEditor(text: $segment.englishText)
                        .frame(height: 60)
                        .padding(4)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Vocabulary Form

struct VocabularyForm: View {
    @Bindable var viewModel: CreateStoryViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Auto Extract Button
            Button {
                viewModel.autoExtractVocabulary()
            } label: {
                Label("Auto-extract Vocabulary", systemImage: "wand.and.stars")
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.hikayaOrange.opacity(0.1))
            .foregroundStyle(Color.hikayaOrange)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Words List
            FormSection(title: "Vocabulary Words") {
                VStack(spacing: 12) {
                    ForEach($viewModel.vocabulary) { $word in
                        WordEditor(word: $word, onDelete: {
                            if let index = viewModel.vocabulary.firstIndex(where: { $0.id == word.id }) {
                                viewModel.removeWord(at: index)
                            }
                        })
                    }
                    
                    Button {
                        viewModel.addWord()
                    } label: {
                        Label("Add Word", systemImage: "plus.circle")
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.hikayaTeal.opacity(0.1))
                    .foregroundStyle(Color.hikayaTeal)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
    }
}

// MARK: - Word Editor

struct WordEditor: View {
    @Binding var word: CreateStoryViewModel.WordDraft
    let onDelete: () -> Void
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(word.arabicText.isEmpty ? "New Word" : word.arabicText)
                    .font(.subheadline.weight(.semibold))
                
                Spacer()
                
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
            
            if isExpanded {
                VStack(spacing: 8) {
                    TextField("Arabic Word", text: $word.arabicText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .environment(\.layoutDirection, .rightToLeft)
                    
                    TextField("Transliteration", text: $word.transliteration)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("English Meaning", text: $word.englishMeaning)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Picker("Part of Speech", selection: $word.partOfSpeech) {
                        ForEach(PartOfSpeech.allCases, id: \.self) { pos in
                            Text(pos.displayName).tag(pos)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Story Preview

struct StoryPreview: View {
    @Bindable var viewModel: CreateStoryViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Preview Card
            VStack(alignment: .leading, spacing: 12) {
                if let imageData = viewModel.coverImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Text(viewModel.title)
                    .font(.title2.weight(.bold))
                
                Text("By \(viewModel.author)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack {
                    DifficultyBadge(level: viewModel.difficultyLevel)
                    
                    Text(viewModel.category.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                }
                
                Text(viewModel.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                
                Divider()
                
                Text("\(viewModel.segments.count) segments")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("\(viewModel.vocabulary.count) vocabulary words")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Step Navigation

struct StepNavigation: View {
    @Bindable var viewModel: CreateStoryViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            // Back Button
            if viewModel.currentStep != .content {
                Button {
                    withAnimation {
                        if let currentIndex = CreationStep.allCases.firstIndex(of: viewModel.currentStep),
                           currentIndex > 0 {
                            viewModel.currentStep = CreationStep.allCases[currentIndex - 1]
                        }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                        .frame(width: 50, height: 50)
                        .background(Color(.secondarySystemBackground))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            // Next/Save Button
            Button {
                withAnimation {
                    if viewModel.currentStep == .preview {
                        Task {
                            await viewModel.saveStory()
                        }
                    } else if let currentIndex = CreationStep.allCases.firstIndex(of: viewModel.currentStep),
                              currentIndex < CreationStep.allCases.count - 1 {
                        viewModel.currentStep = CreationStep.allCases[currentIndex + 1]
                    }
                }
            } label: {
                HStack {
                    Text(viewModel.currentStep == .preview ? "Save Story" : "Next")
                        .font(.headline.weight(.semibold))
                    
                    if viewModel.currentStep != .preview {
                        Image(systemName: "chevron.right")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(viewModel.isValid ? Color.hikayaTeal : Color.gray)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!viewModel.isValid || viewModel.isSaving)
        }
    }
}

// MARK: - Preview

#Preview {
    CreateStoryView()
        .modelContainer(for: [Story.self, Word.self], inMemory: true)
}
