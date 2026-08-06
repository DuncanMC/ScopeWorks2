//
//  FolderBookmarkManager.swift

//  ScopeWorks2
//
//  Manages security-scoped bookmarks for the app's 3 shared folders:
//  Source Images, Documents, and Snapshots.
//

import Foundation
import SwiftUI
import Combine

class FolderBookmarkManager: ObservableObject {
    static let shared = FolderBookmarkManager()
    
    // MARK: - Folder roles
    
    enum FolderRole: String, CaseIterable {
        case sourceImages = "ScopeWorksSourceImagesBookmark"
        case documents    = "ScopeWorksDocumentsBookmark"
        case snapshots    = "ScopeWorksSnapshotsBookmark"
        
        var displayName: String {
            switch self {
            case .sourceImages: return "Source Images"
            case .documents:    return "Documents"
            case .snapshots:    return "Saved Images"
            }
        }
        
        var suggestedFolderName: String {
            switch self {
            case .sourceImages: return "ScopeWorks Source Images"
            case .documents:    return "ScopeWorks Documents"
            case .snapshots:    return "ScopeWorks images"
            }
        }
        
        var setupPrompt: String {
            switch self {
            case .sourceImages:
                return "Select or create a folder for your kaleidoscope source images.\nSuggested: iCloud Drive > \(suggestedFolderName)"
            case .documents:
                return "Select or create a folder for ScopeWorks documents.\nSuggested: iCloud Drive > \(suggestedFolderName)"
            case .snapshots:
                return "Select or create a folder for saved snapshot images.\nSuggested: iCloud Drive > \(suggestedFolderName)"
            }
        }
    }
    
    // MARK: - Published folder URLs (resolved at launch)
    
    @Published var sourceImagesURL: URL?
    @Published var documentsURL: URL?
    @Published var snapshotsURL: URL?
    
    /// True when all 3 folder bookmarks have been configured.
    var isSetupComplete: Bool {
        UserDefaults.standard.bool(forKey: "folderSetupComplete")
    }
    
    // MARK: - Bookmark storage
    
    /// Saves a security-scoped bookmark for the given folder role.
    func saveBookmark(for role: FolderRole, url: URL) {
        do {
            #if os(macOS)
            let data = try url.bookmarkData(options: [.withSecurityScope])
            #else
            let data = try url.bookmarkData()
            #endif
            UserDefaults.standard.set(data, forKey: role.rawValue)
            
            // Update the published URL
            switch role {
            case .sourceImages: sourceImagesURL = url
            case .documents:    documentsURL = url
            case .snapshots:    snapshotsURL = url
            }
            
            print("Saved bookmark for \(role.displayName): \(url.path)")
        } catch {
            print("Failed to save bookmark for \(role.displayName): \(error.localizedDescription)")
        }
    }
    
    /// Resolves a previously saved bookmark for the given folder role.
    /// Returns the resolved URL, or nil if no bookmark exists or resolution fails.
    @discardableResult
    func resolveBookmark(for role: FolderRole) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: role.rawValue) else {
            return nil
        }
        
        var isStale = false
        do {
            #if os(macOS)
            let url = try URL(resolvingBookmarkData: data,
                              options: [.withSecurityScope],
                              bookmarkDataIsStale: &isStale)
            #else
            let url = try URL(resolvingBookmarkData: data,
                              bookmarkDataIsStale: &isStale)
            #endif
            
            let _ = url.startAccessingSecurityScopedResource()
            
            // Refresh stale bookmark
            if isStale {
                saveBookmark(for: role, url: url)
            }
            
            return url
        } catch {
            print("Failed to resolve bookmark for \(role.displayName): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Resolves all 3 folder bookmarks. Call at app launch (non-first-launch).
    func resolveAllBookmarks() {
        sourceImagesURL = resolveBookmark(for: .sourceImages)
        documentsURL = resolveBookmark(for: .documents)
        snapshotsURL = resolveBookmark(for: .snapshots)
    }
    
    // MARK: - Relative path helpers
    
    /// Returns the path of `fileURL` relative to the source images folder,
    /// or nil if the file is not inside that folder tree.
    func relativePathFromSourceImages(for fileURL: URL) -> String? {
        guard let sourceDir = sourceImagesURL else { return nil }
        let sourcePath = sourceDir.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        
        guard filePath.hasPrefix(sourcePath) else { return nil }
        
        // Remove the source folder prefix and leading slash
        var relative = String(filePath.dropFirst(sourcePath.count))
        if relative.hasPrefix("/") {
            relative = String(relative.dropFirst())
        }
        return relative.isEmpty ? nil : relative
    }
    
    /// Resolves a relative path back to a full URL using the source images folder.
    func resolveRelativePath(_ relativePath: String) -> URL? {
        guard let sourceDir = sourceImagesURL else { return nil }
        let url = sourceDir.appendingPathComponent(relativePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    
    // MARK: - URL for a specific role
    
    func url(for role: FolderRole) -> URL? {
        switch role {
        case .sourceImages: return sourceImagesURL
        case .documents:    return documentsURL
        case .snapshots:    return snapshotsURL
        }
    }
    
    // MARK: - Bundle image copying
    
    /// Copies any missing bundle images to the source images folder.
    /// Safe to call on every launch — only copies files that don't already exist.
    func copyBundleImagesToSourceFolder() {
        guard let destFolder = sourceImagesURL else { return }
        
        let accessing = destFolder.startAccessingSecurityScopedResource()
        defer { if accessing { destFolder.stopAccessingSecurityScopedResource() } }
        
        guard let bundleImageURLs = Bundle.main.urls(
            forResourcesWithExtension: nil,
            subdirectory: "ScopeWorks source images"
        ) else { return }
        
        for fileURL in bundleImageURLs {
            let destURL = destFolder.appendingPathComponent(fileURL.lastPathComponent)
            if !FileManager.default.fileExists(atPath: destURL.path) {
                do {
                    try FileManager.default.copyItem(at: fileURL, to: destURL)
                    print("Copied bundle image: \(fileURL.lastPathComponent)")
                } catch {
                    print("Failed to copy \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }
    }
    
    func copyBundleDocumentsToDocumentsFolder() {
        guard let destFolder = documentsURL else { return }
        let accessing = destFolder.startAccessingSecurityScopedResource()
        defer { if accessing { destFolder.stopAccessingSecurityScopedResource() } }
        
        guard let bundleDocumentURLs = Bundle.main.urls(
            forResourcesWithExtension: nil,
            subdirectory: "ScopeWorks documents"
        ) else { return }
        
        for fileURL in bundleDocumentURLs {
            let destURL = destFolder.appendingPathComponent(fileURL.lastPathComponent)
            if !FileManager.default.fileExists(atPath: destURL.path) {
                do {
                    try FileManager.default.copyItem(at: fileURL, to: destURL)
                    print("Copied document: \(fileURL.lastPathComponent)")
                } catch {
                    print("Failed to copy \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }
        
    }
    private init() {
        
    }
}
