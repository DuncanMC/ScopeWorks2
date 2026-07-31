//
//  ImageSouceView.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 7/3/26.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import PhotosUI

struct ImageSouceView: View {

    @ObservedObject var scopeState: ScopeState
    @StateObject private var cameraManager: CameraManager
    
    /// Tracks whether to default the file picker to the source images folder
    /// or the last-used directory.
    @AppStorage("useSourceImagesFolder") private var useSourceImagesFolder = true
    
    #if os(iOS)
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var filePickerDelegate: ImageFilePickerDelegate?
    #endif

    var dismissClosure: (() -> Void)

    init(scopeState: ScopeState, dismissClosure: @escaping () -> Void) {
        self.scopeState = scopeState
        self.dismissClosure = dismissClosure

        // Create or reuse the CameraManager so its @Published properties drive the UI
        if let existing = scopeState.cameraManager {
            _cameraManager = StateObject(wrappedValue: existing)
        } else {
            let device = MTLCreateSystemDefaultDevice()!
            let manager = CameraManager(metalDevice: device, scopeState: scopeState)
            scopeState.cameraManager = manager
            _cameraManager = StateObject(wrappedValue: manager)
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Image Source")
                .font(.headline)
                .padding([.leading, .trailing], 50)
            
            Spacer()
            
            // MARK: - Load from File
            VStack(spacing: 8) {
                Button("Load from File") {
                    loadFromFile()
                }
                .frame(minWidth: 160)
                
                // Toggle between source images folder and last-used directory
                if FolderBookmarkManager.shared.sourceImagesURL != nil {
                    Toggle("Start in Source Images folder", isOn: $useSourceImagesFolder)
                        .font(.caption)
                        .toggleStyle(.switch)
                        .frame(maxWidth: 250)
                }
            }
            
            // MARK: - Load from Photo Library
            #if os(iOS)
            PhotosPicker("Load from Photo Library", selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared())
                .frame(minWidth: 160)
                .onChange(of: selectedPhotoItem) {
                    Task { @MainActor in
                        guard let item = selectedPhotoItem else { return }
                        scopeState.isHEIC = item.supportedContentTypes.contains(UTType.heic)
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            scopeState.selectedImageID = item.itemIdentifier
                            scopeState.selectedImageData = data
                            scopeState.imageSourceInfo = .fromPhotoLibrary(
                                id: item.itemIdentifier ?? "",
                                filename: nil
                            )
                            scopeState.switchToStaticImage()
                            dismissClosure()
                        }
                    }
                }
            #else
            Button("Load from Photo Library") {
                // On macOS, use NSOpenPanel filtered to common image types
                // pointing at the user's Pictures folder
                loadFromPhotoLibraryMacOS()
            }
            .frame(minWidth: 160)
            #endif
            
            Divider().padding(.horizontal, 20)

            // MARK: - Camera
#if os(macOS)
            if !cameraManager.availableDevices.isEmpty {
                Menu("Camera") {
                    ForEach(cameraManager.availableDevices, id: \.uniqueID) { device in
                        Button(device.localizedName) {
                            Task {
                                scopeState.cameraDescription = device.localizedName
                                await scopeState.startCamera(deviceID: device.uniqueID)
                                dismissClosure()
                            }
                        }
                    }
                }
            }
#else
            Button("Front Camera") {
                Task {
                    let frontDevice = AVCaptureDevice.default(
                        .builtInWideAngleCamera, for: .video, position: .front)
                    scopeState.cameraDescription = frontDevice?.localizedName ?? ""

                    await scopeState.startCamera(deviceID: frontDevice?.uniqueID)
                    dismissClosure()
                }
            }
            Button("Rear Camera") {
                Task {
                    let rearDevice = AVCaptureDevice.default(
                        .builtInWideAngleCamera, for: .video, position: .back)
                    scopeState.cameraDescription = rearDevice?.localizedName ?? ""
                    await scopeState.startCamera(deviceID: rearDevice?.uniqueID)
                    dismissClosure()
                }
            }
#endif

            if scopeState.imageSourceMode != .staticImage {
                Button("Stop Camera") {
                    scopeState.switchToStaticImage()
                }
                .foregroundColor(.red)
            }

            Button("Dismiss") {
                dismissClosure()
            }
            .padding(.bottom, 20)
        }
        .padding(.all, 20)
    }
    
    // MARK: - File loading
    
    /// The directory URL to start the file picker in.
    private var filePickerStartDirectory: URL? {
        if useSourceImagesFolder {
            return FolderBookmarkManager.shared.sourceImagesURL
        }
        // Try last-used directory from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "lastUsedImageDirectoryBookmark") {
            var isStale = false
            #if os(macOS)
            let opts: URL.BookmarkResolutionOptions = [.withSecurityScope]
            #else
            let opts: URL.BookmarkResolutionOptions = []
            #endif
            if let url = try? URL(resolvingBookmarkData: data, options: opts, bookmarkDataIsStale: &isStale) {
                return url
            }
        }
        return FolderBookmarkManager.shared.sourceImagesURL
    }
    
    private func loadFromFile() {
        #if os(macOS)
        loadFromFileMacOS()
        #else
        loadFromFileIOS()
        #endif
    }
    
    #if os(macOS)
    private func loadFromFileMacOS() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .tiff, .heic].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.directoryURL = filePickerStartDirectory
        panel.contentMinSize = NSSize(width: 800, height: 500)
        
        if panel.runModal() == .OK, let url = panel.url {
            handleSelectedFile(url)
        }
    }
    
    private func loadFromPhotoLibraryMacOS() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .tiff, .heic, .gif, .bmp].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.directoryURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        panel.contentMinSize = NSSize(width: 800, height: 500)
        
        if panel.runModal() == .OK, let url = panel.url {
            handleSelectedFile(url)
        }
    }
    #endif
    
    #if os(iOS)
    private func loadFromFileIOS() {
        let types: [UTType] = [.jpeg, .png, .tiff, .heic].compactMap { $0 }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.allowsMultipleSelection = false
        picker.modalPresentationStyle = .fullScreen
        if let dir = filePickerStartDirectory {
            picker.directoryURL = dir
        }
        
        let delegate = ImageFilePickerDelegate()
        delegate.onPick = { url in
            handleSelectedFile(url)
            self.filePickerDelegate = nil
        }
        self.filePickerDelegate = delegate
        picker.delegate = delegate
        
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first,
           let rootVC = keyWindow.rootViewController {
            var presentingVC = rootVC
            while let presented = presentingVC.presentedViewController {
                presentingVC = presented
            }
            presentingVC.present(picker, animated: true)
        }
    }
    #endif
    
    /// Handles a file URL selected from any file picker.
    private func handleSelectedFile(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        
        // Read image data synchronously while security-scoped access is active
        guard let data = try? Data(contentsOf: url) else {
            print("Failed to read image data from \(url.lastPathComponent)")
            return
        }
        
        // Set the URL and data directly (don't rely on imageURL's async didSet)
        scopeState.imageURL = url
        scopeState.selectedImageData = data
        
        // Create bookmark for the file
        #if os(macOS)
        let bookmarkData = try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess])
        #else
        let bookmarkData = try? url.bookmarkData()
        #endif
        scopeState.bookmarkData = bookmarkData
        
        // Check HEIC
        if let typeID = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier {
            scopeState.isHEIC = typeID == UTType.heic.identifier
        }
        
        // Populate imageSourceInfo
        scopeState.imageSourceInfo = .fromFile(url: url, bookmarkData: bookmarkData)
        
        // Remember the directory for next time
        let dirURL = url.deletingLastPathComponent()
        saveLastUsedDirectory(dirURL)
        
        scopeState.switchToStaticImage()
        dismissClosure()
    }
    
    /// Saves a bookmark for the last-used directory.
    private func saveLastUsedDirectory(_ dirURL: URL) {
        #if os(macOS)
        let data = try? dirURL.bookmarkData(options: [.withSecurityScope])
        #else
        let data = try? dirURL.bookmarkData()
        #endif
        if let data {
            UserDefaults.standard.set(data, forKey: "lastUsedImageDirectoryBookmark")
        }

        // If the directory is NOT the source images folder, remember that
        let sourceURL = FolderBookmarkManager.shared.sourceImagesURL
        if let sourceURL, !dirURL.standardizedFileURL.path.hasPrefix(sourceURL.standardizedFileURL.path) {
            useSourceImagesFolder = false
        }

        #if os(macOS)
        // The image picker moved the system's remembered panel directory here.
        // Pin it back to the document folder for the DocumentGroup panels —
        // this picker doesn't rely on it (it sets directoryURL explicitly).
        // Delayed because the panel service writes its memory asynchronously.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ScopeState.seedDocumentPanelDirectory()
        }
        #endif
    }
}

// MARK: - iOS File Picker Delegate
#if os(iOS)
private class ImageFilePickerDelegate: NSObject, UIDocumentPickerDelegate {
    var onPick: ((URL) -> Void)?
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        onPick?(url)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        onPick = nil
    }
}
#endif

#Preview {
    ImageSouceView(scopeState: ScopeState(), dismissClosure: {})
}
