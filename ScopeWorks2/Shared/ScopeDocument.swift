// ScopeDocument.swift
// Document model for ScopeWorks2 based on Codable ScopeState

import SwiftUI
import UniformTypeIdentifiers
import Combine

// Register custom document UTType
extension UTType {
    static var scopeworksDocument: UTType {
        UTType(exportedAs: "com.wareto.scopeworks2.document")
    }
}

struct ScopeDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.scopeworksDocument] }
    
    private var cancellables = Set<AnyCancellable>()

    @State private var changedDate: Date? = nil
    
    // The actual document data
    var scopeState: ScopeState

    private func makeDirty() {
        self.changedDate = Date()
        #if os(macOS)
            let documentController: NSDocumentController = .shared
            if let document = documentController.currentDocument {
                document.updateChangeCount(.changeDone)
            }
        #endif
        
    }
    private func doInitSetup() {
        
        NotificationCenter.default.addObserver(
            forName: requestSaveDocument,
            object: nil,
            queue: .main
        ) { _ in
            makeDirty()
        }
    }
    // MARK: - FileDocument protocol
    init() {
        scopeState = ScopeState()
        doInitSetup()
        // Avoid capturing `self` from a struct in escaping closures. If you need to
        // react to save requests, forward the notification to a free function or
        // a static handler that does not require `self`.
    }
    
    
    @MainActor
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoder = JSONDecoder()
        scopeState = try decoder.decode(ScopeState.self, from: data)
        doInitSetup()
    }
    
    @MainActor
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        let data = try encoder.encode(scopeState)
        return .init(regularFileWithContents: data)
    }
}

