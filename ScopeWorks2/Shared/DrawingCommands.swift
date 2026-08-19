//
//  DrawingCommands.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 7/1/26.
//  Copyright (c) 2026 Duncan Champney. All rights reserved.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: macOS menubar / iPadOS menu
struct ScopeWorksCommands: Commands {

    @FocusedObject var scopeState: ScopeState?
    #if os(macOS)
    @Environment(\.newDocument) private var newDocument
    #endif

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
                createKaleidoscopeFromImageMetadata()
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

#if os(macOS)
    // MARK: - Create Kaleidoscope from Image Metadata (macOS)

    /// Prompts for a PNG/JPEG/TIFF image and builds a new document from the
    /// kaleidoscope info embedded in its metadata (see ScopeState.writeImage).
    /// Decoding the state runs the normal image-resolution chain: the source
    /// image loads automatically if it's in the designated source images
    /// folder, and otherwise the existing relocation flow asks the user to
    /// locate it.
    private func createKaleidoscopeFromImageMetadata() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose an image that was saved with kaleidoscope info included"
        panel.directoryURL = FolderBookmarkManager.shared.snapshotsURL

        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let jsonData = ScopeState.kaleidoscopeInfoData(fromImageAt: url) else {
            showMetadataAlert(
                title: "No Kaleidoscope Info Found",
                message: MetadataImportText.noInfoMessage(imageName: url.lastPathComponent)
            )
            return
        }

        do {
            let state = try JSONDecoder().decode(ScopeState.self, from: jsonData)
            let document = ScopeDocument(scopeState: state)
            newDocument { document }
        } catch {
            showMetadataAlert(
                title: "Couldn’t Read Kaleidoscope Info",
                message: MetadataImportText.unreadableMessage(imageName: url.lastPathComponent)
            )
            print("Failed to decode kaleidoscope info: \(error)")
        }
    }

    private func showMetadataAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
#endif
}

/// User-facing messages shared by the macOS and iOS import flows.
enum MetadataImportText {
    static func noInfoMessage(imageName: String) -> String {
        "“\(imageName)” does not contain kaleidoscope info. "
            + "Only images saved by ScopeWorks with “Include kaleidoscope info "
            + "in saved images” enabled can be used."
    }

    static func unreadableMessage(imageName: String) -> String {
        "The kaleidoscope info in “\(imageName)” could not be read. "
            + "It may have been created by an incompatible version of ScopeWorks."
    }
}

#if os(iOS)
// MARK: - Create Kaleidoscope from Image Metadata (iOS)

/// The iOS "Create Kaleidoscope from Image Data" flow, invoked from a
/// NewDocumentButton on the document launch screen. Prompts for a PNG/JPEG/
/// TIFF image and returns a document prepared from the embedded kaleidoscope
/// info; SwiftUI then opens it as a new untitled document — the same result
/// as creating a new kaleidoscope and configuring it by hand.
enum MetadataImport {

    /// Called by NewDocumentButton's prepareDocument closure. Throws
    /// CancellationError to abort document creation (on cancel or when the
    /// chosen image has no usable kaleidoscope info).
    @MainActor
    static func prepareDocument() async throws -> ScopeDocument? {
        guard let url = await pickImage() else {
            throw CancellationError()
        }

        // Files picked outside our sandbox need security-scoped access
        // while we read their metadata.
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let jsonData = ScopeState.kaleidoscopeInfoData(fromImageAt: url) else {
            showAlert(
                title: "No Kaleidoscope Info Found",
                message: MetadataImportText.noInfoMessage(imageName: url.lastPathComponent)
            )
            throw CancellationError()
        }

        do {
            let state = try JSONDecoder().decode(ScopeState.self, from: jsonData)
            return ScopeDocument(scopeState: state)
        } catch {
            showAlert(
                title: "Couldn’t Read Kaleidoscope Info",
                message: MetadataImportText.unreadableMessage(imageName: url.lastPathComponent)
            )
            print("Failed to decode kaleidoscope info: \(error)")
            throw CancellationError()
        }
    }

    /// Presents the document picker and resolves with the picked image URL,
    /// or nil if the user cancels.
    @MainActor
    private static func pickImage() async -> URL? {
        await withCheckedContinuation { continuation in
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.png, .jpeg, .tiff])
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

    private static func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presentOnTopViewController(alert)
    }

    /// Presents a view controller above whatever is currently frontmost.
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
