// ScopeDocument.swift
// Document model for ScopeWorks2 based on Codable ScopeState

import SwiftUI
import UniformTypeIdentifiers
import Combine

// Register custom document UTType
extension UTType {
    nonisolated static var scopeworksDocument: UTType {
        UTType(exportedAs: "com.wareto.scopeworks2.document")
    }
}

@MainActor
final class ScopeDocument: ReferenceFileDocument {
    typealias Snapshot = Data

    nonisolated static var readableContentTypes: [UTType] { [.scopeworksDocument] }

    nonisolated static var writableContentTypes: [UTType] { [.scopeworksDocument] }

    private var cancellables = Set<AnyCancellable>()

    // The actual document data
    var scopeState: ScopeState

    private func doInitSetup() {
        scopeState.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    // MARK: - FileDocument protocol
    nonisolated init() {
        scopeState = ScopeState()
        Task { @MainActor [self] in
            doInitSetup()
        }
    }
    
    
    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoder = JSONDecoder()
        scopeState = try decoder.decode(ScopeState.self, from: data)
        doInitSetup()
    }
    
    func snapshot(contentType: UTType) throws -> Data {
        //print("In function \(#function)")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(scopeState)
    }

    
    nonisolated func fileWrapper(snapshot: Data, configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: snapshot)
    }

}

