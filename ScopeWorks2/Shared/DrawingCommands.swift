//
//  DrawingCommands.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 7/1/26.
//  Copyright (c) 2026 Duncan Champney. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: macOS menubar / iPadOS menu
struct ScopeWorksCommands: Commands {

    @FocusedObject var scopeState: ScopeState?

    var body: some Commands {

        CommandGroup(before: .saveItem) {
            Button("Save Image as") {
                scopeState?.saveImageAs()
            }
            .keyboardShortcut("s", modifiers: .option)
            .disabled(scopeState == nil)
            Button("Record Video") {
                scopeState?.recordVideo()
            }
            .disabled(scopeState == nil)
            #if os(macOS)
            // On iOS this action lives on the document launch screen, where
            // NewDocumentButton can open the prepared document directly.
            Button("Create Kaleidoscope from Image Metadata…") {
                MetadataImport.promptAndCreateKaleidoscope()
            }
            #endif
        }
        CommandGroup(before: .toolbar) {
            ForEach(ScopeCommand.viewCommands) { command in
                if command.isToggle, let kp = command.keyPath {
                    Toggle(command.label, isOn: Binding(
                        get: {
                            return scopeState?[keyPath: kp] ?? false
                        },
                        set: {
                            scopeState?[keyPath: kp] = $0
                        }
                    ))
                    .keyboardShortcut(command.shortcutKey, modifiers: command.shortcutModifiers)
                    .disabled(command.disableCommandClosure(scopeState))
                } else {
                    Button(command.label) {
                        guard let scopeState else { return }
                        command.performAction(on: scopeState)
                    }
                    .keyboardShortcut(command.shortcutKey, modifiers: command.shortcutModifiers)
                    .disabled(command.disableCommandClosure(scopeState))
                }
            }


            Divider()

            Button("Close External Display") {
                scopeState?.externalDisplayViewManager?.selectedDisplayID = nil
            }
            .keyboardShortcut(.escape, modifiers: [])
            .disabled(scopeState?.externalDisplayViewManager?.selectedDisplayID == nil)
        }
        CommandGroup(replacing: .help) {
            Button("ScopeWorks Help") {
                scopeState?.presentedModal = .help
            }
            .keyboardShortcut("/")
            .disabled(scopeState == nil)
        }
    }
}

// MARK: - Create Kaleidoscope from Image Metadata

/// Errors surfaced to the user when importing kaleidoscope info from an image.
enum MetadataImportError: LocalizedError {
    case noMetadata(imageName: String)
    case unreadable(imageName: String)

    var alertTitle: String {
        switch self {
        case .noMetadata: return "No Kaleidoscope Info Found"
        case .unreadable: return "Couldn’t Read Kaleidoscope Info"
        }
    }

    var errorDescription: String? {
        switch self {
        case .noMetadata(let imageName):
            return "“\(imageName)” does not contain kaleidoscope info. "
                + "Only images saved by ScopeWorks with “Include kaleidoscope info "
                + "in saved images” enabled can be used."
        case .unreadable(let imageName):
            return "The kaleidoscope info in “\(imageName)” could not be read. "
                + "It may have been created by an incompatible version of ScopeWorks."
        }
    }
}

/// The "Create Kaleidoscope from Image Data" implementation, shared by every
/// entry point: the macOS File menu command and Finder "Open With"/dock
/// drag-and-drop, and the iOS launch-screen button and Files "Open in".
/// Also converts legacy flat .ksp2 documents arriving through the same entry
/// points into new "<name> (converted)" .kspp package documents.
enum MetadataImport {

    /// Image types that can carry embedded kaleidoscope info.
    static let importableTypes: [UTType] = [.png, .jpeg, .tiff]

    /// True if the URL points to a file type that may carry kaleidoscope info.
    static func isImportableImage(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return importableTypes.contains { type.conforms(to: $0) }
    }

    /// True if the URL points to a legacy flat-file .ksp2 document (as
    /// opposed to a directory, which is an old package saved with the .ksp2
    /// extension).
    static func isLegacyFlatDocument(_ url: URL) -> Bool {
        guard url.pathExtension.lowercased() == "ksp2" else { return false }
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        return values?.isDirectory != true
    }

    /// "<original name> (converted)" — the name given to the document created
    /// when a legacy flat .ksp2 file is opened.
    private static func convertedBaseName(forLegacyDocumentAt url: URL) -> String {
        "\((url.lastPathComponent as NSString).deletingPathExtension) (converted)"
    }

    /// Decodes the ScopeState embedded in the given image's metadata.
    /// Decoding runs the normal image-resolution chain: the source image loads
    /// automatically if it's in the designated source images folder, and
    /// otherwise the existing relocation flow asks the user to locate it.
    static func extractState(fromImageAt url: URL) throws -> ScopeState {
        // Files from outside our sandbox (pickers, "Open With", "Open in")
        // need security-scoped access while we read their metadata.
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let jsonData = ScopeState.kaleidoscopeInfoData(fromImageAt: url) else {
            throw MetadataImportError.noMetadata(imageName: url.lastPathComponent)
        }
        do {
            return try JSONDecoder().decode(ScopeState.self, from: jsonData)
        } catch {
            print("Failed to decode kaleidoscope info: \(error)")
            throw MetadataImportError.unreadable(imageName: url.lastPathComponent)
        }
    }

    /// Creates a kaleidoscope document from the image at `url`, presenting an
    /// alert if the image has no usable kaleidoscope info.
    @MainActor
    static func createKaleidoscope(fromImageAt url: URL) {
        do {
            let state = try extractState(fromImageAt: url)
            try openDocument(with: state, imageName: url.lastPathComponent)
        } catch let error as MetadataImportError {
            showAlert(title: error.alertTitle, message: error.errorDescription ?? "")
        } catch {
            showAlert(title: "Couldn’t Create Kaleidoscope",
                      message: error.localizedDescription)
        }
    }

    /// Encodes the state in the .ksp2 document format.
    private static func documentData(for state: ScopeState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(state)
    }

    private static func documentBaseName(forImageName imageName: String) -> String {
        "Kaleidoscope from \((imageName as NSString).deletingPathExtension)"
    }

#if os(macOS)

    /// The File menu command: prompts for an image, then imports it.
    @MainActor
    static func promptAndCreateKaleidoscope() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = importableTypes
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose an image that was saved with kaleidoscope info included"
        panel.directoryURL = FolderBookmarkManager.shared.snapshotsURL

        guard panel.runModal() == .OK, let url = panel.url else { return }
        createKaleidoscope(fromImageAt: url)
    }

    /// Opens the state as a new untitled document. Writes the state to a
    /// temporary .ksp2 file and opens an untitled duplicate of it through
    /// NSDocumentController — unlike SwiftUI's newDocument environment action,
    /// this works from any context, including the app delegate handling
    /// Finder "Open With" and dock drag-and-drop.
    @MainActor
    private static func openDocument(with state: ScopeState, imageName: String) throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("ksp2")
        try documentData(for: state).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try NSDocumentController.shared.duplicateDocument(
            withContentsOf: tempURL,
            copying: true,
            displayName: documentBaseName(forImageName: imageName)
        )
    }

    /// Opens a legacy flat .ksp2 file as a new untitled "<name> (converted)"
    /// document, leaving the original file untouched; saving writes the new
    /// .kspp package format.
    @MainActor
    static func openConvertedLegacyDocument(at url: URL) {
        do {
            try NSDocumentController.shared.duplicateDocument(
                withContentsOf: url,
                copying: true,
                displayName: convertedBaseName(forLegacyDocumentAt: url)
            )
            print("Opened legacy document \(url.lastPathComponent) as untitled converted document")
        } catch {
            print("Failed to open converted copy of \(url.lastPathComponent): \(error)")
            NSApp.presentError(error)
        }
    }

    @MainActor
    private static func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

#elseif os(iOS)

    /// Called by the launch screen's NewDocumentButton prepareDocument
    /// closure: prompts for an image and returns a document prepared from the
    /// embedded kaleidoscope info; SwiftUI then opens it as a new untitled
    /// document. Throws CancellationError to abort document creation (on
    /// cancel or when the chosen image has no usable kaleidoscope info).
    @MainActor
    static func prepareDocument() async throws -> ScopeDocument? {
        guard let url = await pickImage() else {
            throw CancellationError()
        }
        do {
            return ScopeDocument(scopeState: try extractState(fromImageAt: url))
        } catch let error as MetadataImportError {
            showAlert(title: error.alertTitle, message: error.errorDescription ?? "")
            throw CancellationError()
        }
    }

    /// Opens a legacy flat .ksp2 file by writing its contents as a new
    /// "<name> (converted).kspp" package in the documents folder and opening
    /// that copy in the document browser, so it lives (and auto-saves) in the
    /// default documents directory. The original file is left untouched.
    @MainActor
    static func openConvertedLegacyDocument(at url: URL) {
        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let json = try Data(contentsOf: url)
            // Validate the contents before creating a document from them.
            _ = try JSONDecoder().decode(ScopeState.self, from: json)
            let documentURL = try writeDocumentFile(
                json: json,
                baseName: convertedBaseName(forLegacyDocumentAt: url)
            )
            openInDocumentBrowser(documentURL, retriesRemaining: 3)
        } catch {
            showAlert(
                title: "Couldn’t Open Document",
                message: "“\(url.lastPathComponent)” could not be converted "
                    + "to the current document format: \(error.localizedDescription)"
            )
        }
    }

    /// Creates a real "Kaleidoscope from <image>.kspp" document file and asks
    /// the launch screen's document browser to open it — the same code path
    /// as the user tapping the file in the browser, which is the only
    /// reliable way to open a document on iOS (SwiftUI offers no programmatic
    /// open, and modals presented from the launch scene are non-interactive).
    @MainActor
    private static func openDocument(with state: ScopeState, imageName: String) throws {
        let documentURL = try writeDocumentFile(for: state, imageName: imageName)
        openInDocumentBrowser(documentURL, retriesRemaining: 3)
    }

    /// Hands the document URL to the document browser's own delegate, exactly
    /// as if the user had picked the file. On a cold launch the browser may
    /// not exist yet, so retry briefly before falling back to an alert.
    @MainActor
    private static func openInDocumentBrowser(_ url: URL, retriesRemaining: Int) {
        if let browser = findDocumentBrowser(), let delegate = browser.delegate {
            delegate.documentBrowser?(browser, didPickDocumentsAt: [url])
        } else if retriesRemaining > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                openInDocumentBrowser(url, retriesRemaining: retriesRemaining - 1)
            }
        } else {
            showAlert(
                title: "Kaleidoscope Document Created",
                message: "“\(url.lastPathComponent)” was created in your ScopeWorks "
                    + "documents folder. Open it from the document browser."
            )
        }
    }

    /// The retained browser-delegate proxy (the browser holds its delegate
    /// weakly).
    @MainActor private static var legacyPickInterceptor: LegacyConvertingBrowserDelegate?

    /// Wraps the launch screen document browser's delegate so that tapping a
    /// legacy flat .ksp2 file converts it to a "<name> (converted).kspp"
    /// package instead of opening it in place — the browser reports picks
    /// directly to DocumentGroup, bypassing the scene delegate's URL
    /// interception. Idempotent; retries briefly on a cold launch while the
    /// browser is still being created.
    @MainActor
    static func installLegacyDocumentInterceptor(retriesRemaining: Int = 3) {
        guard let browser = findDocumentBrowser() else {
            if retriesRemaining > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    installLegacyDocumentInterceptor(retriesRemaining: retriesRemaining - 1)
                }
            }
            return
        }
        guard let delegate = browser.delegate,
              !(delegate is LegacyConvertingBrowserDelegate) else { return }
        let interceptor = LegacyConvertingBrowserDelegate(wrapping: delegate)
        legacyPickInterceptor = interceptor
        browser.delegate = interceptor
    }

    /// The UIDocumentBrowserViewController hosted by the launch screen's
    /// bottom sheet, found by walking the app's view controller hierarchies.
    @MainActor
    private static func findDocumentBrowser() -> UIDocumentBrowserViewController? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                if let browser = findBrowser(in: window.rootViewController) {
                    return browser
                }
            }
        }
        return nil
    }

    @MainActor
    private static func findBrowser(in viewController: UIViewController?) -> UIDocumentBrowserViewController? {
        guard let viewController else { return nil }
        if let browser = viewController as? UIDocumentBrowserViewController {
            return browser
        }
        if let found = findBrowser(in: viewController.presentedViewController) {
            return found
        }
        for child in viewController.children {
            if let found = findBrowser(in: child) {
                return found
            }
        }
        return nil
    }

    private static func writeDocumentFile(for state: ScopeState, imageName: String) throws -> URL {
        try writeDocumentFile(json: documentData(for: state),
                              baseName: documentBaseName(forImageName: imageName))
    }

    /// Writes document JSON as "<baseName>.kspp" in the designated documents
    /// folder (falling back to the app's local Documents directory),
    /// avoiding name collisions. Returns the URL of the new file.
    private static func writeDocumentFile(json: Data, baseName: String) throws -> URL {
        if let designated = FolderBookmarkManager.shared.documentsURL {
            let accessing = designated.startAccessingSecurityScopedResource()
            defer { if accessing { designated.stopAccessingSecurityScopedResource() } }
            if let url = try? write(json, named: baseName, in: designated) {
                return url
            }
        }
        let localDocuments = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return try write(json, named: baseName, in: localDocuments)
    }

    private static func write(_ data: Data, named baseName: String, in folder: URL) throws -> URL {
        var destination = folder.appendingPathComponent(baseName + ".kspp")
        var counter = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = folder.appendingPathComponent("\(baseName) \(counter).kspp")
            counter += 1
        }
        // Write in the current package format (a directory containing
        // document.json), matching what ScopeDocument saves.
        let json = FileWrapper(regularFileWithContents: data)
        json.preferredFilename = ScopeDocument.packageJSONFilename
        let package = FileWrapper(directoryWithFileWrappers: [
            ScopeDocument.packageJSONFilename: json
        ])
        try package.write(to: destination, options: .atomic, originalContentsURL: nil)
        return destination
    }

    /// Presents the document picker and resolves with the picked image URL,
    /// or nil if the user cancels.
    @MainActor
    private static func pickImage() async -> URL? {
        await withCheckedContinuation { continuation in
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: importableTypes)
            picker.allowsMultipleSelection = false
            picker.directoryURL = FolderBookmarkManager.shared.snapshotsURL

            let delegate = MetadataImagePickerDelegate()
            delegate.onFinish = { url in
                continuation.resume(returning: url)
            }
            // The picker holds its delegate weakly; keep it alive until dismissal.
            MetadataImagePickerDelegate.active = delegate
            picker.delegate = delegate
            presentOnTopViewController(picker)
        }
    }

    @MainActor
    private static func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presentOnTopViewController(alert)
    }

    /// Presents a view controller above whatever is currently frontmost.
    @MainActor
    private static func presentOnTopViewController(_ viewController: UIViewController) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow })
                ?? windowScene.windows.first,
              let rootVC = keyWindow.rootViewController else { return }
        var presentingVC = rootVC
        while let presented = presentingVC.presentedViewController {
            presentingVC = presented
        }
        presentingVC.present(viewController, animated: true)
    }

#endif
}

#if os(iOS)
/// Wraps DocumentGroup's document-browser delegate so that picking a legacy
/// flat .ksp2 file converts it to a "<name> (converted).kspp" package (which
/// is then opened) instead of opening the legacy file in place. Every other
/// delegate callback passes through to the wrapped delegate untouched.
@MainActor
private final class LegacyConvertingBrowserDelegate: NSObject,
                                                     UIDocumentBrowserViewControllerDelegate {
    nonisolated(unsafe) private let wrapped: UIDocumentBrowserViewControllerDelegate

    init(wrapping wrapped: UIDocumentBrowserViewControllerDelegate) {
        self.wrapped = wrapped
    }

    func documentBrowser(_ controller: UIDocumentBrowserViewController,
                         didPickDocumentsAt documentURLs: [URL]) {
        var passthrough: [URL] = []
        for url in documentURLs {
            if MetadataImport.isLegacyFlatDocument(url) {
                MetadataImport.openConvertedLegacyDocument(at: url)
            } else {
                passthrough.append(url)
            }
        }
        if !passthrough.isEmpty {
            wrapped.documentBrowser?(controller, didPickDocumentsAt: passthrough)
        }
    }

    nonisolated override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || wrapped.responds(to: aSelector)
    }

    nonisolated override func forwardingTarget(for aSelector: Selector!) -> Any? {
        wrapped.responds(to: aSelector) ? wrapped : super.forwardingTarget(for: aSelector)
    }
}

/// Document picker delegate for the metadata import flow. The picker holds
/// its delegate weakly, so `active` keeps it alive while the picker is shown.
/// `onFinish` is always called exactly once — with the picked URL, or nil on
/// cancel — so the awaiting continuation always resumes.
private class MetadataImagePickerDelegate: NSObject, UIDocumentPickerDelegate {
    static var active: MetadataImagePickerDelegate?

    var onFinish: ((URL?) -> Void)?

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        onFinish?(urls.first)
        onFinish = nil
        Self.active = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        onFinish?(nil)
        onFinish = nil
        Self.active = nil
    }
}
#endif
