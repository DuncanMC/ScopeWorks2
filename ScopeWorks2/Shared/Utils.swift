//
//  Utils.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 4/10/26.
//

import Foundation
import SwiftUI

func createSecurityScopedBookmark(for url: URL) -> Data? {
    do {
        // Create a bookmark from the selected URL
        let bookmarkData = try url.bookmarkData(options: .securityScopeAllowOnlyReadAccess, includingResourceValuesForKeys: nil, relativeTo: nil)
        return bookmarkData
    } catch {
        print("createSecurityScopedBookmark error \(error)")
        return nil
    }
}

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
