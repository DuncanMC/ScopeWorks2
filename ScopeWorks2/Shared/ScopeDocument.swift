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
    
    /// Baseline snapshot of the encoded state taken after loading.
    /// Used to detect real content changes vs. transient rendering state updates.
    private var baselineSnapshot: Data?
    /// Once a real content change is detected, skip snapshot comparison for efficiency.
    private var contentHasChanged = false

    // The actual document data
    var scopeState: ScopeState

    /// Lightweight encoder for snapshot comparison (no pretty printing needed).
    private static let comparisonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private func doInitSetup() {
        // Capture baseline snapshot AFTER all synchronous setup (including image resolution
        // from ScopeState.doInitSetup). Transient @Published properties like texSize, texAspect,
        // imageUUID are NOT in CodingKeys, so they won't affect the comparison.
        baselineSnapshot = try? Self.comparisonEncoder.encode(scopeState)
        
        scopeState.objectWillChange
            .sink { [weak self] _ in
                // Defer to next run loop iteration so the @Published property
                // has actually been updated (objectWillChange fires BEFORE the change).
                DispatchQueue.main.async { [weak self] in
                    self?.forwardIfContentChanged()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Forwards objectWillChange to the document system only when the encoded
    /// document content has actually changed from the baseline.
    private func forwardIfContentChanged() {
        if contentHasChanged {
            objectWillChange.send()
            return
        }
        guard let current = try? Self.comparisonEncoder.encode(scopeState) else { return }
        if current != baselineSnapshot {
            contentHasChanged = true
            objectWillChange.send()
        }
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
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(scopeState)
        // Update baseline and reset dirty flag so the document starts clean after save
        baselineSnapshot = try? Self.comparisonEncoder.encode(scopeState)
        contentHasChanged = false
        return data
    }

    
    nonisolated func fileWrapper(snapshot: Data, configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: snapshot)
    }

}

