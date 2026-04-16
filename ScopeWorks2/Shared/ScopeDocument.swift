// ScopeDocument.swift
// Document model for ScopeWorks2 based on Codable ScopeState

import SwiftUI
import UniformTypeIdentifiers

struct ScopeDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.scopeworksDocument] }
    
    // The actual document data
    var scopeState: ScopeState

    // MARK: - FileDocument protocol
    init() {
        scopeState = ScopeState()
    }
    
    @MainActor
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoder = JSONDecoder()
        scopeState = try decoder.decode(ScopeState.self, from: data)
    }
    
    @MainActor
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        let data = try encoder.encode(scopeState)
        return .init(regularFileWithContents: data)
    }
}

// Register custom document UTType
extension UTType {
    static var scopeworksDocument: UTType {
        UTType(exportedAs: "com.wareto.scopeworks2.document")
    }
}
