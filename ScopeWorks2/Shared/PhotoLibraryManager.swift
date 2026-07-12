//
//  PhotoLibraryManager.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 4/10/26.
//

import Photos
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum PhotoError: LocalizedError {
    case notAuthorized
    case albumCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Photo library access was denied. Please enable it in Settings."
        case .albumCreationFailed:
            return "Could not create the photo album. Please try again."
        }
    }
}

struct ImageLibraryInfo: Codable {
    let filename: String
    let fileID: String
    let modDate: Date
}

class PhotoLibraryManager {
    
    

    var imageInfo = [ImageLibraryInfo]()

    
//    let sourceImagesFolderName = "Kaleidoscope Source Images"
    static let shared = PhotoLibraryManager()
    private let albumName = "ScopeWorks source images"
    
    // MARK: - Create Album & Copy Images
    
    func imageURLSFromBundle() -> [URL] {
        guard let imageURLS = Bundle.main.urls(forResourcesWithExtension: nil, subdirectory: albumName) else {
            return [URL]()
        }
        return imageURLS
    }
    


    func setupAlbumOnFirstLaunch() async throws {
        // The first-launch source image setup is now handled by FolderBookmarkManager.
        // This method is kept for backward compatibility with existing ScopeState init code.
        // On both platforms, bundle images are copied to the user-selected source images
        // folder during the FirstLaunchSetupView flow.
    }

    private func getOrCreateAlbum(named name: String) async throws -> PHAssetCollection {
        // Check if album already exists
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", name)
        let collections = PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .any, options: fetchOptions
        )

        if let existing = collections.firstObject {
            return existing
        }

        // Create new album
        var albumPlaceholder: PHObjectPlaceholder?
        try await PHPhotoLibrary.shared().performChanges {
            let createRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            albumPlaceholder = createRequest.placeholderForCreatedAssetCollection
        }

        guard let placeholder = albumPlaceholder,
              let album = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [placeholder.localIdentifier],
                options: nil
              ).firstObject else {
            throw PhotoError.albumCreationFailed
        }

        return album
    }
}
//#endif
