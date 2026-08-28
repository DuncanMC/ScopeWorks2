// ScopeDocument.swift
// Document model for ScopeWorks2 based on Codable ScopeState
//
// Documents are saved as a package (directory) containing:
//   document.json  — the encoded ScopeState (same JSON as the legacy format)
//   thumbnail.jpg  — optional 512×512 preview of the kaleidoscope, included
//                    when the "Embed image thumbnails in documents" setting
//                    is on
// Legacy documents (a flat JSON file) are still readable; they are converted
// to the package format the next time they're saved.

import SwiftUI
import UniformTypeIdentifiers
import Combine

// Register custom document UTTypes.
//
// Both types claim the .ksp2 extension; LaunchServices picks per file based
// on physical kind. A package-conforming type's extension tag only binds to
// DIRECTORIES, so without the legacy type, old flat-JSON documents would
// resolve to an anonymous dynamic type and be unopenable.
extension UTType {
    /// The current document format: a package (directory) containing
    /// document.json and an optional thumbnail.jpg.
    nonisolated static var scopeworksDocument: UTType {
        UTType(exportedAs: "com.wareto.scopeworks2.document-package")
    }

    /// The legacy document format: a flat JSON file. Readable (and converted
    /// to the package format on save) but no longer written.
    nonisolated static var scopeworksDocumentLegacy: UTType {
        UTType(exportedAs: "com.wareto.scopeworks2.document-legacy")
    }
}

/// The saved state of a document: the encoded JSON plus an optional
/// 512×512 JPEG thumbnail of the current kaleidoscope.
struct ScopeDocumentSnapshot {
    let json: Data
    let thumbnail: Data?
}

@MainActor
final class ScopeDocument: ReferenceFileDocument {
    typealias Snapshot = ScopeDocumentSnapshot

    /// File names inside the .ksp2 document package.
    nonisolated static let packageJSONFilename = "document.json"
    nonisolated static let packageThumbnailFilename = "thumbnail.jpg"

    nonisolated static var readableContentTypes: [UTType] {
        [.scopeworksDocument, .scopeworksDocumentLegacy]
    }

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
        // While loading from file, keep re-capturing the baseline to absorb
        // initialization side-effects (texture load, triangle-point adjustment,
        // image relocation) without marking the document dirty.
        if scopeState.isLoadingFromFile {
            baselineSnapshot = try? Self.comparisonEncoder.encode(scopeState)
            return
        }
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


    /// Creates a document from an already-decoded state, e.g. one rebuilt
    /// from kaleidoscope info embedded in a saved image's metadata.
    init(scopeState: ScopeState) {
        self.scopeState = scopeState
        doInitSetup()
    }

    required init(configuration: ReadConfiguration) throws {
        let file = configuration.file
        let data: Data
        if file.isRegularFile {
            // Legacy format: the whole document was a flat JSON file.
            guard let contents = file.regularFileContents else {
                throw CocoaError(.fileReadCorruptFile)
            }
            data = contents
        } else if let jsonWrapper = file.fileWrappers?[Self.packageJSONFilename],
                  let contents = jsonWrapper.regularFileContents {
            // Package format: JSON lives in document.json inside the package.
            data = contents
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
        scopeState = try JSONDecoder().decode(ScopeState.self, from: data)
        doInitSetup()
    }

    func snapshot(contentType: UTType) throws -> ScopeDocumentSnapshot {
        print("Entering function \(#function) at \(Date().formatted())")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let json = try encoder.encode(scopeState)
        // Update baseline and reset dirty flag so the document starts clean after save
        baselineSnapshot = try? Self.comparisonEncoder.encode(scopeState)
        contentHasChanged = false

        var thumbnail: Data? = nil
        if UserDefaults.standard.bool(
            forKey: UserDefaultsKeys.embedThumbnailsInDocuments.rawValue) {
            thumbnail = scopeState.documentThumbnailJPEG()
        }

        #if os(macOS)
        //scheduleFinderIconUpdate(thumbnail: thumbnail)
        #endif

        return ScopeDocumentSnapshot(json: json, thumbnail: thumbnail)
    }


    nonisolated func fileWrapper(snapshot: ScopeDocumentSnapshot,
                                 configuration: WriteConfiguration) throws -> FileWrapper {
        #if os(macOS)
        Task {
            let filename = await scopeState.documentFileURL?.lastPathComponent ?? "nil"
            print("Building a fileWrapper for file \(filename) at \(Date().formatted())")
        }
        #endif

        let jsonWrapper = FileWrapper(regularFileWithContents: snapshot.json)
        jsonWrapper.preferredFilename = Self.packageJSONFilename
        var wrappers = [Self.packageJSONFilename: jsonWrapper]

        if let thumbnailData = snapshot.thumbnail {
            let thumbnailWrapper = FileWrapper(regularFileWithContents: thumbnailData)
            thumbnailWrapper.preferredFilename = Self.packageThumbnailFilename
            wrappers[Self.packageThumbnailFilename] = thumbnailWrapper
        }

        return FileWrapper(directoryWithFileWrappers: wrappers)
    }

    // MARK: - Finder per-file icons (macOS)

#if os(macOS)
    /// After the save completes, marks the saved directory as a package and
    /// sets (or clears) the Finder's custom icon for this document from its
    /// thumbnail. Deferred because snapshot() runs before the package is
    /// written to disk.
    private func scheduleFinderIconUpdate(thumbnail: Data?) {
        guard let fileURL = scopeState.documentFileURL else {
            // New untitled document: the file URL isn't known until save-as
            // completes; ContentView applies the icon when the URL appears.
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            Self.markAsPackage(fileURL)
            //Self.applyFinderIcon(thumbnail: thumbnail, at: fileURL)
        }
    }

    /// Sets the filesystem "bundle bit" on the saved document directory so
    /// the Finder always displays it as a single file (openable via "Show
    /// Package Contents"), even when LaunchServices hasn't registered the
    /// app's package type declaration — e.g. stale registrations from older
    /// app copies that declared .ksp2 as a flat type.
    nonisolated static func markAsPackage(_ url: URL) {
        var url = url
        var values = URLResourceValues()
        values.isPackage = true
        do {
            try url.setResourceValues(values)
        } catch {
            print("Failed to set package bit on \(url.path): \(error)")
        }
    }

    /// Sets the Finder custom icon for the file at `url` from thumbnail JPEG
    /// data, or clears any custom icon when data is nil so the file shows the
    /// standard document icon (derived from the app icon).
    nonisolated static func applyFinderIcon(thumbnail: Data?, at url: URL) {
        let icon = thumbnail.flatMap { NSImage(data: $0) }
        NSWorkspace.shared.setIcon(icon, forFile: url.path)
    }

    /// Marks the document at `url` as a package, then reads its thumbnail
    /// (if any) and applies or clears the file's Finder icon accordingly.
    /// Used when a document gains a file URL (open / first save / save-as).
//    nonisolated static func applyFinderIcon(forDocumentAt url: URL) {
//        // Only directories carry the package bit; legacy flat files don't.
//        var isDirectory: ObjCBool = false
//        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
//              isDirectory.boolValue else { return }
//        markAsPackage(url)
//        let thumbnailURL = url.appendingPathComponent(packageThumbnailFilename)
//        let thumbnailData = try? Data(contentsOf: thumbnailURL)
//        applyFinderIcon(thumbnail: thumbnailData, at: url)
//    }
#endif
}
