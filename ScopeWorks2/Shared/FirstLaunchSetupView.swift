//
//  FirstLaunchSetupView.swift
//  ScopeWorks2
//
//  Multi-step wizard presented on first launch to configure the app's
//  3 shared folders: Source Images, Documents, and Snapshots.
//

import SwiftUI
import UniformTypeIdentifiers

struct FirstLaunchSetupView: View {
    @ObservedObject var folderManager: FolderBookmarkManager
    var onComplete: () -> Void
    
    @State private var currentStep = 0
    
    private let steps: [FolderBookmarkManager.FolderRole] = [
        .sourceImages,
        .documents,
        .snapshots
    ]
    
    private var currentRole: FolderBookmarkManager.FolderRole {
        steps[currentStep]
    }
    
    private var isCurrentStepDone: Bool {
        folderManager.url(for: currentRole) != nil
    }
    
    private var allDone: Bool {
        steps.allSatisfy { folderManager.url(for: $0) != nil }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Welcome to ScopeWorks")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 40)
            
            Text("Set up your folders so images and documents can be shared across your devices via iCloud Drive.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            // Step indicator
            HStack(spacing: 12) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentStep ? Color.accentColor :
                              (folderManager.url(for: steps[index]) != nil ? Color.green : Color.gray.opacity(0.3)))
                        .frame(width: 12, height: 12)
                }
            }
            
            // Current step content
            VStack(spacing: 16) {
                Text("Step \(currentStep + 1) of \(steps.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(currentRole.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(currentRole.setupPrompt)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
                
                if let url = folderManager.url(for: currentRole) {
                    Label(url.lastPathComponent, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                }
                
                Button(folderManager.url(for: currentRole) == nil ? "Select Folder" : "Change Folder") {
                    pickFolder(for: currentRole)
                }
                .buttonStyle(.borderedProminent)
                #if os(macOS)
                .controlSize(.large)
                #endif
            }
            .padding(24)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Navigation
            HStack(spacing: 20) {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation { currentStep -= 1 }
                    }
                }
                
                if currentStep < steps.count - 1 {
                    Button("Next") {
                        withAnimation { currentStep += 1 }
                    }
                    .disabled(!isCurrentStepDone)
                } else {
                    Button("Done") {
                        finishSetup()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!allDone)
                }
            }
            .padding(.bottom, 40)
        }
        .frame(minWidth: 500, minHeight: 400)
        .interactiveDismissDisabled()
    }
    
    // MARK: - Folder picker
    
    private func pickFolder(for role: FolderBookmarkManager.FolderRole) {
        #if os(macOS)
        pickFolderMacOS(for: role)
        #else
        pickFolderIOS(for: role)
        #endif
    }
    
    #if os(macOS)
    private func pickFolderMacOS(for role: FolderBookmarkManager.FolderRole) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = "Step \(currentStep + 1): \(role.displayName)"
        panel.message = "Select or create a folder named \"\(role.suggestedFolderName)\".\nTip: Navigate to iCloud Drive and click \"New Folder\" to create it."
        panel.prompt = "Select"
        
        panel.begin { result in
            if result == .OK, let url = panel.url {
                folderManager.saveBookmark(for: role, url: url)
            }
        }
    }
    #endif
    
    #if os(iOS)
    private func pickFolderIOS(for role: FolderBookmarkManager.FolderRole) {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.directoryURL = nil
        picker.title = "Select \"\(role.suggestedFolderName)\" folder"
        
        let delegate = SetupFolderPickerDelegate()
        delegate.onPick = { url in
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            folderManager.saveBookmark(for: role, url: url)
        }
        // Retain the delegate
        _iosFolderPickerDelegate = delegate
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
    
    // Hold a strong reference so the delegate stays alive
    @State private var _iosFolderPickerDelegate: SetupFolderPickerDelegate?
    #endif
    
    // MARK: - Finish
    
    private func finishSetup() {
        // Copy bundle source images to the newly-selected source images folder
        folderManager.copyBundleImagesToSourceFolder()
        
        UserDefaults.standard.set(true, forKey: "folderSetupComplete")
        onComplete()
    }
}

// MARK: - iOS Folder Picker Delegate for Setup

#if os(iOS)
private class SetupFolderPickerDelegate: NSObject, UIDocumentPickerDelegate {
    var onPick: ((URL) -> Void)?
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        onPick?(url)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // User can try again
    }
}
#endif
