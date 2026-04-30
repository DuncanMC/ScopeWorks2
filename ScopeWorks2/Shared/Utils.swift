//
//  Utils.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 4/10/26.
//

import Foundation
import SwiftUI

#if os(macOS)
func createSecurityScopedBookmark(for url: URL) -> Data? {
    do {
        // Create a bookmark from the selected URL
        var fileURL: URL? = nil
        let documentController: NSDocumentController = .shared
        if let document = documentController.currentDocument {
            fileURL = document.fileURL
        }
        let bookmarkData = try url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
//            relativeTo: fileURL
        )
        return bookmarkData
    } catch {
        print("createSecurityScopedBookmark error \(error)")
        return nil
    }
}
#endif

public extension Color {
    func components() -> [Double] {
        var colorComponents: [CGFloat] = [1, 1, 1, 1]
        
        #if os(macOS)
        if let backgroundColor = NSColor(self).cgColor.components {
            colorComponents =  backgroundColor
        }
        #else
        if let backgroundColor = UIColor(self).cgColor.components {
            colorComponents =  backgroundColor
        }
        
        #endif
        return colorComponents.map{ Double($0) }
    }
}
