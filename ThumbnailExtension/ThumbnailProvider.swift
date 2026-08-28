//
//  ThumbnailProvider.swift
//  ScopeWorksThumbnails
//
//  QuickLook thumbnail provider for .ksp2 document packages. Draws the
//  512×512 preview embedded in the package (thumbnail.jpg) when present.
//  When the document has no embedded thumbnail, it returns nil so the system
//  falls back to the standard document icon.
//
//  Used by the iOS Files app and the in-app document browser whenever
//  documents are shown in icon view.
//

import UIKit
import QuickLookThumbnailing

class ThumbnailProvider: QLThumbnailProvider {

    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, Error?) -> Void
    ) {
        // The document is a package; the preview lives at a fixed name inside it.
        let thumbnailURL = request.fileURL.appendingPathComponent("thumbnail.jpg")

        guard let image = UIImage(contentsOfFile: thumbnailURL.path) else {
            // No embedded thumbnail — fall back to the static document icon.
            handler(nil, nil)
            return
        }

        let maximumSize = request.maximumSize
        handler(QLThumbnailReply(contextSize: maximumSize, currentContextDrawing: { () -> Bool in
            // Aspect-fill the requested size, centered.
            let scale = max(maximumSize.width / image.size.width,
                            maximumSize.height / image.size.height)
            let drawSize = CGSize(width: image.size.width * scale,
                                  height: image.size.height * scale)
            let origin = CGPoint(x: (maximumSize.width - drawSize.width) / 2,
                                 y: (maximumSize.height - drawSize.height) / 2)
            image.draw(in: CGRect(origin: origin, size: drawSize))
            return true
        }), nil)
    }
}
