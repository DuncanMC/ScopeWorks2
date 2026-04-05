//
//  main.swift
//  BuildTemplates
//
//  Created by Duncan Champney on 4/2/26.
//

import ArgumentParser
import Foundation
import CoreGraphics

let sqrt3Over10 = sqrt(3) / 10;
let sqrt3Over5 = sqrt(3) / 5;

@main
@available(macOS 12, iOS 15, visionOS 1, tvOS 15, watchOS 8, *)

struct BuildTemplates: AsyncParsableCommand {
    
    func polygonElements() -> [ScopeElement] {
        let elements: [ScopeElement] = [
            //Element 0
            ScopeElement(
                type: .polygon,
                center: CGPointZero,
                radius: 0.2,
                startAngle: 0
            ),
            //Element 1
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: 0.3, y: -sqrt3Over10),
                radius: 0.2,
                startAngle: 0
            ),
            //Element 2
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: 0, y: -sqrt3Over5),
                radius: 0.2,
                startAngle: 0
            ),
            //Element 3
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: -0.3, y: -sqrt3Over10),
                radius: 0.2,
                startAngle: 0
            ),
            //Element 4
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: -0.3, y: sqrt3Over10),
                radius: 0.2,
                startAngle: 0
            ),
            //Element 5
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: 0, y: sqrt3Over5),
                radius: 0.2,
                startAngle: 0
            ),
            //Element 6
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: 0.3, y: sqrt3Over10),
                radius: 0.2,
                startAngle: 0
            ),
            //Element 7
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: 0.6, y: -sqrt3Over5),
                radius: 0.2,
                startAngle: 0
            ),
            //Element 8
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: 0.3, y: -3*sqrt3Over10),
                radius: 0.2,
                startAngle: 0
            ),
//            //Element 9
//            ScopeElement(
//                type: .polygon,
//                center: CGPoint(x: 0.0, y: -2*sqrt3Over5),
//                radius: 0.2,
//                startAngle: 0
//            ),
            //Element 10
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: -0.3, y: -3*sqrt3Over10),
                radius: 0.2,
                startAngle: 0
            ),
            //Element 11
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: -0.6, y: -sqrt3Over5),
                radius: 0.2,
                startAngle: 0
            ),
            //Element 12
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: -0.6, y: 0),
                radius: 0.2,
                startAngle: 0
            ),
            //Element 13
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: -0.6, y: sqrt3Over5),
                radius: 0.2,
                startAngle: 0
            ),
            //Element 14
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: -0.3, y: 3*sqrt3Over10),
                radius: 0.2,
                startAngle: 0
            ),
//            //Element 15
//            ScopeElement(
//                type: .polygon,
//                center: CGPoint(x: 0.0, y: 2*sqrt3Over5),
//                radius: 0.2,
//                startAngle: 0
//            ),
            //Element 16
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: 0.3, y: 3*sqrt3Over10),
                radius: 0.2,
                startAngle: 0
            ),
            //Element 17
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: 0.6, y: sqrt3Over5),
                radius: 0.2,
                startAngle: 0
            ),
            //Element 18
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: 0.6, y: 0),
                radius: 0.2,
                startAngle: 0
            ),
            //Element 19
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: 0.9, y: 3*sqrt3Over10),
                radius: 0.2,
                startAngle: 0
            ),
            //Element 20
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: 0.9, y: sqrt3Over10),
                radius: 0.2,
                startAngle: 0
            ),
            //Element 21
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: 0.9, y: -sqrt3Over10),
                radius: 0.2,
                startAngle: 0
            ),
            //Element 22
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: 0.9, y: -3*sqrt3Over10),
                radius: 0.2,
                startAngle: 0
            ),
            //Element 23
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: -0.9, y: 3*sqrt3Over10),
                radius: 0.2,
                startAngle: 0
            ),
            //Element 24
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: -0.9, y: sqrt3Over10),
                radius: 0.2,
                startAngle: 0
            ),
            //Element 25
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: -0.9, y: -sqrt3Over10),
                radius: 0.2,
                startAngle: 0
            ),
            //Element 26
            ScopeElement(
                type: .polygon,
                center: CGPoint(x: -0.9, y: -3*sqrt3Over10),
                radius: 0.2,
                startAngle: 0
            ),
            ]
        return elements
    }
    
    @Argument(
        help: "A tool to build the contents of the 'Kaleidoscope_templates` folder.",
        completion: .file(), transform: URL.init(fileURLWithPath:))
    var folderURL: URL? = nil
    
    mutating func run() async throws {
        guard let folderURL else {
            fatalError("No path provided")
        }
        let filemanager = FileManager.default
        print("\(folderURL.path)")
        do {
            
            if !filemanager.fileExists(atPath: folderURL.path) {
                try filemanager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            }
        } catch {
            fatalError("Failed to create directory \(folderURL.path) Error: \(error)")
        }
        let templateNames = ["Polygon", "Polygon grid", "8-way square", "8-way tiles"]
        var elements: [ScopeElement]
        var isCircular: Bool
        var sideCount: Int = 6
        for (index, templateName) in templateNames.enumerated() {
            isCircular = true
            sideCount = 6
            elements = [ScopeElement(
                type: .polygon,
                center: CGPoint(x: 0.5, y: 0.5),
                radius: 1.0,
                startAngle:  0.0)]

            switch index {
            case 0: // MARK: Polygon template
                isCircular = true
                elements = [ScopeElement(
                    type: .eightWay,
                    center: CGPoint(x: 0, y: 0),
                    radius: 1.0,
//                    startAngle:  0)]
                startAngle:  Float.pi/6)]
            case 1: // MARK: Polygon grid template
                isCircular = true
                elements = polygonElements()
            case 2: // MARK: 8-way square template
                isCircular = false
                elements = [ScopeElement(
                    type: .eightWay,
                    center: CGPoint(x: 0.5, y: 0.5),
                    radius: 0.5,
                    startAngle:  0.0)]
            case 3: // MARK: 8-way tiles template
                isCircular = false
                elements = [
                    ScopeElement(
                    type: .eightWay,
                    center: CGPoint(x: 0.25, y: 0.25),
                    radius: 0.25,
                    startAngle:  0.0),
                    ScopeElement(
                    type: .eightWay,
                    center: CGPoint(x: 0.25, y: -0.25),
                    radius: 0.25,
                    startAngle:  0.0),
                    ScopeElement(
                    type: .eightWay,
                    center: CGPoint(x: -0.25, y: -0.25),
                    radius: 0.25,
                    startAngle:  0.0),
                    ScopeElement(
                    type: .eightWay,
                    center: CGPoint(x: -0.25, y: 0.25),
                    radius: 0.25,
                    startAngle:  0.0),
                ]
            default:
                fatalError("Invalid index")
            }
            let thisTemplate = ScopeTemplate(
                index: index,
                name: templateName,
                displayDescription: "\(templateName) kaleidoscope.",
                sideCount: sideCount,
                elements: elements,
                isCircular: isCircular,
                modifiedDate: Date(),
            )
            let filename = templateName.replacingOccurrences(of: " ", with: "_").lowercased()
            let fileURL = folderURL.appendingPathComponent("\(filename).json")
            print("About to write \(fileURL.path)")
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
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
