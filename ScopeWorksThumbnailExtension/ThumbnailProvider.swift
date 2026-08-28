//
//  ThumbnailProvider.swift
//  ScopeWorksThumbnailExtension
//
//  Created by Duncan Champney on 8/25/26.
//
//  QuickLook thumbnail provider for .ksp2 document packages. Draws the
//  512×512 preview embedded in the package (thumbnail.jpg) when present.
//  When the document has no embedded thumbnail, it returns nil so the system
//  falls back to the standard document icon.
//
//  Used by the iOS Files app and the in-app document browser whenever
//  documents are shown in icon view.
//


#if os(macOS)
import AppKit
#else
import UIKit
#endif
import Foundation
import QuickLookThumbnailing
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers


final class ThumbnailProvider: QLThumbnailProvider {
    
    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, Error?) -> Void
    ) {
        
//        NSLog("***** SCOPEWORKS THUMBNAIL PROVIDER WAS CALLED *****")
//        NSLog("URL: %@", request.fileURL.path)
        if let type = UTType(filenameExtension: request.fileURL.pathExtension) {
            NSLog("UTI: %@", type.identifier)
        }
        
        let thumbnailURL =
        request.fileURL.appendingPathComponent("thumbnail.jpg")
        
#if canImport(UIKit)
        
        guard let image = UIImage(contentsOfFile: thumbnailURL.path) else {
            handler(nil, nil)
            return
        }
        
#elseif canImport(AppKit)
        
        guard let image = NSImage(contentsOf: thumbnailURL) else {
            handler(nil, nil)
            return
        }
        
#endif
        
        let maximumSize = request.maximumSize
        
        let reply = QLThumbnailReply(
            contextSize: maximumSize,
            currentContextDrawing: {
                
#if canImport(UIKit)
                
                let scale = max(
                    maximumSize.width / image.size.width,
                    maximumSize.height / image.size.height
                )
                
                let drawSize = CGSize(
                    width: image.size.width * scale,
                    height: image.size.height * scale
                )
                
#else
                
                let imageSize = image.size
                
                let scale = max(
                    maximumSize.width / imageSize.width,
                    maximumSize.height / imageSize.height
                )
                
                let drawSize = CGSize(
                    width: imageSize.width * scale,
                    height: imageSize.height * scale
                )
                
#endif
                
                let origin = CGPoint(
                    x: (maximumSize.width - drawSize.width) / 2,
                    y: (maximumSize.height - drawSize.height) / 2
                )
                
                let rect = CGRect(
                    origin: origin,
                    size: drawSize
                )
                
                image.draw(in: rect)
                
                return true
            }
        )
        
        handler(reply, nil)
    }
}
