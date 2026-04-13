//
//  ScopeWorks2App.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 3/18/26.
//

import SwiftUI

@main
struct ScopeWorks2App: App {
    
//    @UIApplicationDelegateAdaptor private var appDelegate: MyAppDelegate

    static var scopeTemplateNamesAndIndexes: [(title: String, index: Int)] = {
        return scopeTemplates.map { (title: $0.name, index: $0.index) }
    }()

    static var scopeTemplateNames: [String] = {
        return scopeTemplates.map { $0.name }
    }()
    
    static var scopeTemplates: [ScopeTemplate] = {
        
//#if os(macOS)
        let fileManager = FileManager.default
        let folderName = "Kaleidoscope_templates"
        do {
            if let bundlePath = Bundle.main.resourcePath {
                //print("bundlePath = \(bundlePath)")
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
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }


}
