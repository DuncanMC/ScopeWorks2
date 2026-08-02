//
//  ScopeWorks2App.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 3/18/26.
//

import SwiftUI

@main
struct ScopeWorks2App: App {
    
    init () {
        UserDefaults.standard.register(defaults: [
            UserDefaultsKeys.includeKaleidoscopeInfoInSavedImages.rawValue: true
        ])

        if let bundlePath = Bundle.main.resourcePath {
            print("----------------------------")
            print("BundlePath = \(bundlePath)")
            print("----------------------------")
        }
        
        // On subsequent launches, resolve all folder bookmarks so they're
        // ready before any document opens.
        if UserDefaults.standard.bool(forKey: "folderSetupComplete") {
            FolderBookmarkManager.shared.resolveAllBookmarks()
            // Copy any new bundle images added in app updates
            FolderBookmarkManager.shared.copyBundleImagesToSourceFolder()
        }

        #if os(macOS)
        // Start the document open/save panels in the last document folder,
        // rather than wherever the last snapshot/image panel left off.
        ScopeState.seedDocumentPanelDirectory()
        #endif
    }
    
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
                print("bundlePath = \(bundlePath)")
            } else {
                print("Can't resolve bundle path")
            }
            guard let kaleidoscopeTemplateURLs = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: folderName) else {
                fatalError("Can't find folder \(folderName)")
            }
            
            
            
            let decoder = JSONDecoder()
            var scopeTemplates = [ScopeTemplate]()
            for aFileURL in kaleidoscopeTemplateURLs {
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
        DocumentGroup(newDocument: { ScopeDocument() }) { configuration in
            ContentView(scopeState: configuration.document.scopeState)
                .focusable()
                .focusedSceneObject(configuration.document.scopeState)
        }
        .defaultSize(width: 1800, height: 1125)
        .commands {
            ScopeWorksCommands()
        }
#if os(iOS)
        // Customizes the document launch screen (shown when no document is
        // open) with an action to rebuild a kaleidoscope from image metadata,
        // alongside the standard create-document action.
        DocumentGroupLaunchScene("ScopeWorks 2") {
            NewDocumentButton("Create New Kaleidoscope")
            // Prompts for an image with embedded kaleidoscope info and opens
            // the prepared state as a new untitled document.
            NewDocumentButton("Create Kaleidoscope from Image Data", for: ScopeDocument.self) {
                try await MetadataImport.prepareDocument()
            }
        }
#endif
#if os(macOS)
        Settings {
            SettingsView(
                selectedAspectRatio: AspectRatio(
                    title: "16:9",
                    width: 16,
                    height: 9,
                    defaultMultiplier: 120,
                    index: 5,
                    isCropForTiling: false),
                         doneButtonAction: {} )
        }
#endif
    }


}
