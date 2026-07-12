//
//  ImageSourceInfo.swift
//  ScopeWorks2
//
//  Describes how the current kaleidoscope source image was loaded.
//  Persisted inside each .KSp2 document for cross-platform image resolution.
//

import Foundation

struct ImageSourceInfo: Codable, Equatable {
    
    enum SourceType: String, Codable {
        case file           // Loaded from disk via file picker
        case photoLibrary   // Loaded from Photos library (iOS)
        case bundleDefault  // One of the bundled sample images
        case none           // No image loaded yet
    }
    
    var sourceType: SourceType = .none
    
    // MARK: - File source fields
    
    /// Absolute URL of the image file (platform-specific, may not resolve on other platforms).
    var fullURL: URL?
    
    /// Path relative to the "ScopeWorks Source Images" folder (e.g. "landscape.png").
    /// This is the key field for cross-platform portability: if both devices have the
    /// same source images folder synced via iCloud, this path resolves on both.
    var relativePathFromSourceImages: String?
    
    /// The filename (last path component), used as a hint when relocating.
    var filename: String?
    
    /// Security-scoped bookmark data for the image file (macOS).
    var bookmarkData: Data?
    
    // MARK: - Photo library fields (iOS)
    
    /// PHAsset local identifier, used to re-fetch the image from the Photos library.
    var photoLibraryID: String?
    
    // MARK: - Convenience initializers
    
    /// Creates an ImageSourceInfo for a file loaded from disk.
    static func fromFile(
        url: URL,
        bookmarkData: Data? = nil
    ) -> ImageSourceInfo {
        let manager = FolderBookmarkManager.shared
        var info = ImageSourceInfo()
        info.sourceType = .file
        info.fullURL = url
        info.filename = url.lastPathComponent
        info.relativePathFromSourceImages = manager.relativePathFromSourceImages(for: url)
        info.bookmarkData = bookmarkData
        return info
    }
    
    /// Creates an ImageSourceInfo for an image from the photo library.
    static func fromPhotoLibrary(id: String, filename: String? = nil) -> ImageSourceInfo {
        var info = ImageSourceInfo()
        info.sourceType = .photoLibrary
        info.photoLibraryID = id
        info.filename = filename
        return info
    }
}
