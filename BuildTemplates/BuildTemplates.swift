//
//  main.swift
//  BuildTemplates
//
//  Created by Duncan Champney on 4/2/26.
//

import ArgumentParser
import Foundation

@main
@available(macOS 12, iOS 15, visionOS 1, tvOS 15, watchOS 8, *)

struct BuildTemplates: AsyncParsableCommand {
    @Argument(
        help: "A tool to build the contents of the 'Kaleidoscope templates` folder.",
        completion: .file(), transform: URL.init(fileURLWithPath:))
    var folderURL: URL? = nil
    
    mutating func run() async throws {
        guard let folderURL else {
            fatalError("No path provided")
        }
        let filemanager = FileManager.default
        do {
            
            if !filemanager.fileExists(atPath: folderURL.path()) {
                try filemanager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            }
        } catch {
            fatalError("Failed to create directory \(folderURL.path) Error: \(error)")
        }
        let templateNames = ["Polygon", "Polygon grid", "8-way square", "8-way tiles"]
        var elements: [ScopeElement]
        var isPolygonType: Bool
        for (index, templateName) in templateNames.enumerated() {
            isPolygonType = true
            elements = [ScopeElement(
                type: .polygon,
                center: CGPoint(x: 0.5, y: 0.5),
                radius: 1.0,
                startAngle:  0.0)]

            switch index {
            case 0: // MARK: Polygon template
                isPolygonType = true
                elements = [ScopeElement(
                    type: .polygon,
                    center: CGPoint(x: 0.5, y: 0.5),
                    radius: 1.0,
                    startAngle:  0.0)]
            case 1: // MARK: Polygon grid template
                break
            case 2: // MARK: 8-way square template
                break
            case 3: // MARK: 8-way tiles template
                break
            default:
                fatalError("Invalid index")
            }
            let thisTemplate = ScopeTemplate(
                index: index,
                name: templateName,
                description: "A \(templateName) template.",
                elements: elements,
                modifiedDate: Date(),
                isPolygonType: isPolygonType
            )
            let fileURL = folderURL.appendingPathComponent("\(templateName.lowercased()).json")
            let encoder = JSONEncoder()
            let data: Data
            do {
                data = try encoder.encode(thisTemplate)
            } catch {
                fatalError("Failed to encode template: \(thisTemplate) Error: \(error)")
            }
            do {
                try data.write(to: fileURL)
            } catch {
                fatalError("Failed to write template to disk: \(thisTemplate) Error: \(error)")
            }
            
            
        }
    }
    
}
