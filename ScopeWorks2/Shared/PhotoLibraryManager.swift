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
        // Check if already done
        
        if let bundlePath = Bundle.main.resourceURL?.path as String? {
            print("Bundle path: \(bundlePath)")
        }
        #if os(macOS)
            // TODO: Make this code create the "ScopeWorks Source images" folder in Documents.
            return
        #else
        UserDefaults.standard.set(false, forKey: "albumCreated")

        guard !UserDefaults.standard.bool(forKey: "albumCreated") else { return }
        do {
            if let data = UserDefaults.standard.data(forKey: "imageInfo") {
                imageInfo = try JSONDecoder().decode([ImageLibraryInfo].self, from: data)
            }
        } catch {
            print("Error reading image data. Error = \(error)")
        }

        // Request authorization
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoError.notAuthorized
        }

        // Create album if it doesn't exist
        let album = try await getOrCreateAlbum(named: albumName)

        let imageURLs = imageURLSFromBundle()
        // Add images to album
        try await PHPhotoLibrary.shared().performChanges {
            let addRequest = PHAssetCollectionChangeRequest(for: album)
            for imageURL in imageURLs {
                guard let imageData = try? Data(contentsOf: imageURL)  else { continue }

                #if os(macOS)
                    guard let image = NSImage(data: imageData) else { continue }
                #else
                    guard let image = UIImage(data: imageData) else { continue }
                #endif
                let creationRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                if let placeholder = creationRequest.placeholderForCreatedAsset {
                    addRequest?.addAssets([placeholder] as NSArray)
                    let identifier = placeholder.localIdentifier
                    // TODO: add the filename, modified date, and identifier for this image to UserDefaults
                    
                    let imageInfo = ImageLibraryInfo(
                        filename: imageURL.lastPathComponent,
                        fileID: identifier,
                        modDate: Date())
                    self.imageInfo.append(imageInfo)
                }
            }
        }

        guard let imageInfo = try? JSONEncoder().encode(self.imageInfo) else { return }
        UserDefaults.standard.set(imageInfo, forKey: "imageInfo")
        UserDefaults.standard.set(true, forKey: "albumCreated")
#endif

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
