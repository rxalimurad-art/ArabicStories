//
//  JSONImportViewModel.swift
//  Hikaya
//  ViewModel for importing stories from JSON
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

@Observable
class JSONImportViewModel {
    // Dependencies
    private let dataService = DataService.shared
    
    // State
    var importState: ImportState = .idle
    var validationResult: ValidationResult?
    var importResult: ImportResult?
    var errorMessage: String?
    
    // Progress
    var importProgress: Double = 0.0
    var currentStoryIndex: Int = 0
    var totalStoriesToImport: Int = 0
    
    enum ImportState {
        case idle
        case validating
        case validationFailed
        case readyToImport
        case importing
        case completed
        case error
    }
    
    // MARK: - File Import
    
    func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                errorMessage = "No file selected"
                importState = .error
                return
            }
            // Security-scoped resource access
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Cannot access file"
                importState = .error
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                validateJSON(data)
            } catch {
                errorMessage = "Failed to read file: \(error.localizedDescription)"
                importState = .error
            }
            
        case .failure(let error):
            errorMessage = error.localizedDescription
            importState = .error
        }
    }
    
    func handlePastedJSON(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else {
            errorMessage = "Invalid text encoding"
            importState = .error
            return
        }
        
        validateJSON(data)
    }
    
    // MARK: - Validation
    
    private func validateJSON(_ data: Data) {
        importState = .validating
        
        Task {
            let importer = JSONStoryImporter(context: dataService.modelContext)
            let result = importer.validateJSON(data)
            
            await MainActor.run {
                self.validationResult = result
                self.totalStoriesToImport = result.storyCount
                
                if result.isValid {
                    self.importState = .readyToImport
                } else {
                    self.importState = .validationFailed
                    if !result.errors.isEmpty {
                        self.errorMessage = result.errors.map { "\($0.field): \($0.message)" }.joined(separator: "\n")
                    }
                }
            }
        }
    }
    
    // MARK: - Import
    
    func importJSON(from data: Data) async {
        importState = .importing
        importProgress = 0.0
        currentStoryIndex = 0
        
        do {
            let result = try await dataService.importStories(from: data)
            
            await MainActor.run {
                self.importResult = result
                self.importState = .completed
                self.importProgress = 1.0
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.importState = .error
            }
        }
    }
    
    func importValidatedJSON() async {
        guard let validationResult = validationResult,
              let jsonData = try? JSONSerialization.data(withJSONObject: try? JSONSerialization.jsonObject(with: Data())) else {
            return
        }
        
        // Note: In a real implementation, we'd store the original data during validation
        // For now, this is a placeholder
    }
    
    // MARK: - Reset
    
    func reset() {
        importState = .idle
        validationResult = nil
        importResult = nil
        errorMessage = nil
        importProgress = 0.0
        currentStoryIndex = 0
        totalStoriesToImport = 0
    }
    
    // MARK: - Computed Properties
    
    var canImport: Bool {
        importState == .readyToImport
    }
    
    var hasErrors: Bool {
        !(validationResult?.errors.isEmpty ?? true)
    }
    
    var hasWarnings: Bool {
        !(validationResult?.warnings.isEmpty ?? true)
    }
    
    var statusMessage: String {
        switch importState {
        case .idle:
            return "Select a JSON file to import"
        case .validating:
            return "Validating JSON..."
        case .validationFailed:
            return "Validation failed. Please fix the errors."
        case .readyToImport:
            return "Ready to import \(totalStoriesToImport) stories"
        case .importing:
            return "Importing stories... (\(currentStoryIndex)/\(totalStoriesToImport))"
        case .completed:
            if let result = importResult {
                return "Successfully imported \(result.storiesImported) stories and \(result.wordsImported) words"
            }
            return "Import completed"
        case .error:
            return errorMessage ?? "An error occurred"
        }
    }
    
    var statusColor: Color {
        switch importState {
        case .idle:
            return .secondary
        case .validating:
            return .orange
        case .validationFailed, .error:
            return .red
        case .readyToImport:
            return .green
        case .importing:
            return .blue
        case .completed:
            return .green
        }
    }
}

// MARK: - Document Types

extension UTType {
    static var json: UTType {
        UTType(filenameExtension: "json")!
    }
}
