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
            relativeTo: fileURL
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

public typealias AspectAndMultiplier = (width: Double, height: Double, multiplier: Double)
public func calcAspectAndMultiplier(width: Int, height: Int) -> AspectAndMultiplier{

    let max = Int(sqrt(Double(max(width, height))) + 1)
    var newAspectHeight = height
    var newAspectWidth = width
    let primes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, 223, 227, 229, 233, 239, 241, 251, 257, 263, 269, 271, 277, 281, 283, 293, 307, 311, 313, 317, 331, 337, 347, 349, 353, 359, 367, 373, 379, 383, 389, 397, 401, 409, 419, 421, 431, 433, 439, 443, 449, 457, 461, 463, 467, 479, 487, 491, 499, 503, 509, 521, 523, 541, 547, 557, 563, 569, 571, 577, 587, 593, 599, 601, 607, 613, 617, 619, 631, 641, 643, 647, 653, 659, 661, 673, 677, 683, 691, 701, 709, 719, 727, 733, 739, 743, 751, 757, 761, 769, 773, 787, 797, 809, 811, 821, 823, 827, 829, 839, 853, 857, 859, 863, 877, 881, 883, 887, 907, 911, 919, 929, 937, 941, 947, 953, 967, 971, 977, 983, 991, 997, 1009, 1013, 1019, 1021, 1031, 1033, 1039, 1049, 1051, 1061, 1063, 1069, 1087, 1091, 1093, 1097, 1103, 1109, 1117, 1123, 1129, 1151, 1153, 1163, 1171, 1181, 1187, 1193, 1201, 1213, 1217, 1223]
    
    for prime in primes {
        guard prime < max else {
            break
        }
        while newAspectHeight % prime == 0 && newAspectWidth % prime == 0 {
            newAspectHeight /= prime
            newAspectWidth /= prime
        }
    }
    if newAspectHeight == 0 { newAspectHeight = 1 }
    if newAspectWidth == 0 { newAspectWidth = 1 }
    let currentMultiplier = Double(width) / Double(newAspectWidth)
    return (width: Double(newAspectWidth), height: Double(newAspectHeight), multiplier: currentMultiplier)
}
