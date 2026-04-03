//
//  ScopeWorks2App.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 3/18/26.
//

import SwiftUI

@main
struct ScopeWorks2App: App {

    static var scopeTemplateNames: [String] = {
        return scopeTemplates.map { $0.name }
    }()
    
    static var scopeTemplates: [ScopeTemplate] = {
        
//#if os(macOS)
        let fileManager = FileManager.default
        let folderName = "Kaleidoscope_templates"
        do {
            if let bundlePath = Bundle.main.resourcePath {
//                print("bundlePath = \(bundlePath)")
            } else {
                print("Can't resolve bundle path")
            }
            guard let kaleidoscopeTemplateURLs = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: folderName) else {
                fatalError("Can't find folder \(folderName)")
            }
            
            
            
            let decoder = JSONDecoder()
            var scopeTemplates = [ScopeTemplate]()
            for aFileURL in kaleidoscopeTemplateURLs {
//                print("filename = \(aFileURL.path)")
                let data = try Data(contentsOf: aFileURL)
                let aScopeTemplate = try decoder.decode(ScopeTemplate.self, from: data)
                scopeTemplates.append(aScopeTemplate)
            }
            return scopeTemplates.sorted() { lhv, rhv in
                return lhv.index < rhv.index
                
            }
        } catch {
            fatalError("Error \(error) reading template files")
        }
//#else
//        
//        let jsonFileStrings: [String] =
//        [
//            """
//            {
//              "elements" : [
//                {
//                  "radius" : 1,
//                  "centerY" : 0,
//                  "startAngle" : 0,
//                  "type" : 1,
//                  "centerX" : 0
//                }
//              ],
//              "name" : "Polygon",
//              "index" : 0,
//              "modifiedDate" : 796934605.6286,
//              "displayDescription" : "Polygon kaleidoscope.",
//              "sideCount" : 6,
//              "isCircular" : true
//            }
//            """
//            ,
//            """
//            {
//              "displayDescription" : "Polygon grid kaleidoscope.",
//              "name" : "Polygon grid",
//              "isCircular" : true,
//              "index" : 1,
//              "sideCount" : 6,
//              "elements" : [
//                {
//                  "type" : 0,
//                  "startAngle" : 0,
//                  "centerX" : 0,
//                  "centerY" : 0,
//                  "radius" : 0.2
//                },
//                {
//                  "centerY" : -0.17320508075688773,
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "type" : 0,
//                  "centerX" : 0.3
//                },
//                {
//                  "centerY" : -0.34641016151377546,
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "type" : 0,
//                  "centerX" : 0
//                },
//                {
//                  "centerY" : -0.17320508075688773,
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "type" : 0,
//                  "centerX" : -0.3
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : -0.3,
//                  "centerY" : 0.17320508075688773,
//                  "type" : 0
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : 0,
//                  "centerY" : 0.34641016151377546,
//                  "type" : 0
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : 0.3,
//                  "centerY" : 0.17320508075688773,
//                  "type" : 0
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : 0.6,
//                  "centerY" : -0.34641016151377546,
//                  "type" : 0
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : 0.3,
//                  "centerY" : -0.5196152422706632,
//                  "type" : 0
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : 0,
//                  "centerY" : -0.6928203230275509,
//                  "type" : 0
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : -0.3,
//                  "centerY" : -0.5196152422706632,
//                  "type" : 0
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : -0.6,
//                  "centerY" : -0.34641016151377546,
//                  "type" : 0
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : -0.6,
//                  "centerY" : 0,
//                  "type" : 0
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : -0.6,
//                  "centerY" : 0.34641016151377546,
//                  "type" : 0
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : -0.3,
//                  "centerY" : 0.5196152422706632,
//                  "type" : 0
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : 0,
//                  "centerY" : 0.6928203230275509,
//                  "type" : 0
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : 0.3,
//                  "centerY" : 0.5196152422706632,
//                  "type" : 0
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : 0.6,
//                  "centerY" : 0.34641016151377546,
//                  "type" : 0
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : 0.6,
//                  "centerY" : 0,
//                  "type" : 0
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : 0.9,
//                  "centerY" : 0.5196152422706632,
//                  "type" : 0
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : 0.9,
//                  "centerY" : 0.5196152422706632,
//                  "type" : 0
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : 0.9,
//                  "centerY" : -0.17320508075688773,
//                  "type" : 0
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : 0.9,
//                  "centerY" : -0.5196152422706632,
//                  "type" : 0
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : -0.9,
//                  "centerY" : 0.5196152422706632,
//                  "type" : 0
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : -0.9,
//                  "centerY" : 0.17320508075688773,
//                  "type" : 0
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : -0.9,
//                  "centerY" : -0.17320508075688773,
//                  "type" : 0
//                },
//                {
//                  "radius" : 0.2,
//                  "startAngle" : 0,
//                  "centerX" : -0.9,
//                  "centerY" : -0.5196152422706632,
//                  "type" : 0
//                }
//              ],
//              "modifiedDate" : 796934605.629516
//            }
//            """
//            ,
//            """
//            {
//              "name" : "8-way square",
//              "index" : 2,
//              "elements" : [
//                {
//                  "startAngle" : 0,
//                  "radius" : 0.5,
//                  "centerX" : 0.5,
//                  "centerY" : 0.5,
//                  "type" : 1
//                }
//              ],
//              "modifiedDate" : 796934605.629803,
//              "sideCount" : 6,
//              "displayDescription" : "8-way square kaleidoscope.",
//              "isCircular" : false
//            }
//            """
//            ,
//            """
//            {
//              "name" : "8-way tiles",
//              "index" : 3,
//              "elements" : [
//                {
//                  "startAngle" : 0,
//                  "radius" : 0.25,
//                  "centerX" : 0.25,
//                  "centerY" : 0.25,
//                  "type" : 1
//                },
//                {
//                  "startAngle" : 0,
//                  "radius" : 0.25,
//                  "centerX" : 0.25,
//                  "centerY" : -0.25,
//                  "type" : 1
//                },
//                {
//                  "startAngle" : 0,
//                  "radius" : 0.25,
//                  "centerX" : -0.25,
//                  "centerY" : -0.25,
//                  "type" : 1
//                },
//                {
//                  "startAngle" : 0,
//                  "radius" : 0.25,
//                  "centerX" : -0.25,
//                  "centerY" : 0.25,
//                  "type" : 1
//                }
//              ],
//              "modifiedDate" : 796934605.629949,
//              "sideCount" : 6,
//              "displayDescription" : "8-way tiles kaleidoscope.",
//              "isCircular" : false
//            }
//            """
//        ]
//        
//        let decoder = JSONDecoder()
//        var scopeTemplates = [ScopeTemplate]()
//        for aJsonString in jsonFileStrings {
//            do {
//                guard let data = aJsonString.data(using: .utf8)
//                     
//            else {
//                    fatalError("Splat.")
//                }
//                let aTemplate = try decoder.decode(ScopeTemplate.self, from: data)
//            scopeTemplates.append(aTemplate)
//            } catch {
//                print("Error = \(error)")
//            }
//        }
//        return scopeTemplates
//#endif
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }


}
