//
//  PhotoLibraryManager.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 4/10/26.
//

import Photos
#if os(iOS) || os(iPadOS)
import UIKit

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

class PhotoLibraryManager {
    static let shared = PhotoLibraryManager()
    private let albumName = "ScopeWorks source images"
    
    // MARK: - Create Album & Copy Images

    func setupAlbumOnFirstLaunch(images: [UIImage]) async throws {
        // Check if already done
        guard !UserDefaults.standard.bool(forKey: "albumCreated") else { return }

        // Request authorization
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoError.notAuthorized
        }

        // Create album if it doesn't exist
        let album = try await getOrCreateAlbum(named: albumName)

        // Add images to album
        try await PHPhotoLibrary.shared().performChanges {
            let addRequest = PHAssetCollectionChangeRequest(for: album)
            for image in images {
                let creationRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                if let placeholder = creationRequest.placeholderForCreatedAsset {
                    addRequest?.addAssets([placeholder] as NSArray)
                    let identifier = placeholder.localIdentifier
                    // TODO: add the filename, modified date, and identifier for this image to UserDefaults
                }
            }
        }

        UserDefaults.standard.set(true, forKey: "albumCreated")
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
#endif
