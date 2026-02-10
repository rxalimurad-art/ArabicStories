//
//  JSONImportView.swift
//  Hikaya
//  JSON import utility with validation UI
//

import SwiftUI
import UniformTypeIdentifiers

struct JSONImportView: View {
    @State private var viewModel = JSONImportViewModel()
    @State private var showingFilePicker = false
    @State private var pastedJSON = ""
    @State private var showingPasteSheet = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.hikayaBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Status Card
                    StatusCard(viewModel: viewModel)
                    
                    // Validation Results
                    if let result = viewModel.validationResult {
                        ValidationResultsCard(result: result)
                    }
                    
                    // Import Results
                    if let result = viewModel.importResult {
                        ImportResultsCard(result: result)
                    }
                    
                    Spacer()
                    
                    // Action Buttons
                    ActionButtons(
                        viewModel: viewModel,
                        onFileTap: { showingFilePicker = true },
                        onPasteTap: { showingPasteSheet = true },
                        onImportTap: {
                            // Import logic
                        },
                        onResetTap: { viewModel.reset() },
                        onDoneTap: { dismiss() }
                    )
                    .padding()
                }
            }
            .navigationTitle("Import Stories")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                viewModel.handleFileImport(result: result)
            }
            .sheet(isPresented: $showingPasteSheet) {
                PasteJSONSheet(
                    pastedJSON: $pastedJSON,
                    onSubmit: {
                        viewModel.handlePastedJSON(pastedJSON)
                        showingPasteSheet = false
                    }
                )
            }
        }
    }
}

// MARK: - Status Card

struct StatusCard: View {
    var viewModel: JSONImportViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(viewModel.statusColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 36))
                    .foregroundStyle(viewModel.statusColor)
            }
            
            // Status Text
            Text(viewModel.statusMessage)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            // Progress Bar (when importing)
            if viewModel.importState == .importing {
                ProgressView(value: viewModel.importProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .hikayaTeal))
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        .padding()
    }
    
    private var statusIcon: String {
        switch viewModel.importState {
        case .idle: return "square.and.arrow.down"
        case .validating: return "hourglass"
        case .validationFailed: return "exclamationmark.triangle"
        case .readyToImport: return "checkmark.circle"
        case .importing: return "arrow.down.circle"
        case .completed: return "checkmark.seal.fill"
        case .error: return "xmark.octagon"
        }
    }
}

// MARK: - Validation Results Card

struct ValidationResultsCard: View {
    let result: ValidationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: result.isValid ? "checkmark.shield" : "exclamationmark.shield")
                    .foregroundStyle(result.isValid ? .green : .orange)
                
                Text("Validation Results")
                    .font(.headline.weight(.semibold))
                
                Spacer()
                
                Text("\(result.storyCount) stories")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
            }
            
            if !result.errors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Errors")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                    
                    ForEach(result.errors.prefix(3)) { error in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(error.field)
                                    .font(.caption.weight(.medium))
                                Text(error.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if result.errors.count > 3 {
                        Text("+ \(result.errors.count - 3) more errors")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.red.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            if !result.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Warnings")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                    
                    ForEach(result.warnings.prefix(2)) { warning in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(warning.field)
                                    .font(.caption.weight(.medium))
                                Text(warning.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
    }
}

// MARK: - Import Results Card

struct ImportResultsCard: View {
    let result: ImportResult
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(spacing: 4) {
                    Text("\(result.storiesImported)")
                        .font(.title.weight(.bold))
                        .foregroundStyle(Color.hikayaTeal)
                    Text("Stories")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                
                VStack(spacing: 4) {
                    Text("\(result.wordsImported)")
                        .font(.title.weight(.bold))
                        .foregroundStyle(Color.hikayaOrange)
                    Text("Words")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                
                VStack(spacing: 4) {
                    Text("\(result.errors.count)")
                        .font(.title.weight(.bold))
                        .foregroundStyle(result.errors.isEmpty ? .green : .red)
                    Text("Errors")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
    }
}

// MARK: - Action Buttons

struct ActionButtons: View {
    var viewModel: JSONImportViewModel
    let onFileTap: () -> Void
    let onPasteTap: () -> Void
    let onImportTap: () -> Void
    let onResetTap: () -> Void
    let onDoneTap: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            switch viewModel.importState {
            case .idle, .validationFailed, .error:
                HStack(spacing: 12) {
                    Button(action: onFileTap) {
                        HStack {
                            Image(systemName: "doc")
                            Text("Select File")
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.hikayaTeal)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button(action: onPasteTap) {
                        HStack {
                            Image(systemName: "doc.on.clipboard")
                            Text("Paste JSON")
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.hikayaOrange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                
            case .readyToImport:
                Button(action: onImportTap) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Import \(viewModel.totalStoriesToImport) Stories")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.hikayaTeal)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button(action: onResetTap) {
                    Text("Start Over")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
            case .completed:
                Button(action: onDoneTap) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Done")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
            default:
                EmptyView()
            }
        }
    }
}

// MARK: - Paste JSON Sheet

struct PasteJSONSheet: View {
    @Binding var pastedJSON: String
    let onSubmit: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $pastedJSON)
                    .font(.system(.body, design: .monospaced))
                    .padding(4)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                
                Button(action: onSubmit) {
                    Text("Validate & Import")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.hikayaTeal)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(pastedJSON.isEmpty)
                .padding()
            }
            .navigationTitle("Paste JSON")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    JSONImportView()
}
