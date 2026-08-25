//
//  ScopeWorks2App.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 3/18/26.
//

import SwiftUI

struct ScopeTypeNameAndIndex: Identifiable, Hashable {
    let title: String
    let index: Int
    var id: Self { self }
}

#if os(iOS)
/// On iOS, DocumentGroup's machinery swallows incoming file-open URLs before
/// SwiftUI's onOpenURL handlers see them, so images arriving via Files
/// "Open in ScopeWorks" must be intercepted at the UIKit scene level.
/// This delegate assigns ImportSceneDelegate to the app's window scenes,
/// preserving the Info.plist configuration for the external-display role.
class IOSAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if connectingSceneSession.role == .windowExternalDisplayNonInteractive {
            // Loads the "External Display" configuration from Info.plist,
            // including its ExternalDisplaySceneDelegate.
            return UISceneConfiguration(name: "External Display",
                                        sessionRole: connectingSceneSession.role)
        }
        let config = UISceneConfiguration(name: nil,
                                          sessionRole: connectingSceneSession.role)
        config.delegateClass = ImportSceneDelegate.self
        return config
    }
}

/// Receives file-open URLs for the app's main window scenes. Image URLs are
/// queued and imported once the scene is active (on a cold launch the UI
/// isn't ready to present alerts when the URL arrives).
class ImportSceneDelegate: NSObject, UIWindowSceneDelegate {
    private var pendingImportURLs: [URL] = []

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        queueImports(connectionOptions.urlContexts)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        queueImports(URLContexts)
        processPendingImports()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        processPendingImports()
    }

    private func queueImports(_ contexts: Set<UIOpenURLContext>) {
        pendingImportURLs.append(
            contentsOf: contexts.map(\.url).filter(MetadataImport.isImportableImage)
        )
    }

    private func processPendingImports() {
        guard !pendingImportURLs.isEmpty else { return }
        let urls = pendingImportURLs
        pendingImportURLs = []
        // Deferred so the scene's UI is fully established before the pending
        // import drives modal presentation — on a cold launch, setting it
        // during activation races the launch screen's own setup.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            for url in urls {
                MetadataImport.createKaleidoscope(fromImageAt: url)
            }
        }
    }
}
#endif

#if os(macOS)
/// Routes files the Finder asks the app to open ("Open With", dragging files
/// onto the app or dock icon). PNG/JPEG/TIFF images run the
/// create-kaleidoscope-from-image-metadata import; everything else (.ksp2)
/// goes through the normal document machinery. Implementing
/// application(_:open:) takes over ALL open requests, so the forwarding for
/// non-image files is required.
class MacAppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if MetadataImport.isImportableImage(url) {
                MetadataImport.createKaleidoscope(fromImageAt: url)
            } else {
                NSDocumentController.shared.openDocument(
                    withContentsOf: url, display: true
                ) { _, _, error in
                    if let error {
                        NSApp.presentError(error)
                    }
                }
            }
        }
    }
}
#endif

@main
struct ScopeWorks2App: App {
    @Environment(\.openWindow) public static var openWindow
    #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
    #elseif os(iOS)
    @UIApplicationDelegateAdaptor(IOSAppDelegate.self) private var appDelegate
    #endif

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
            FolderBookmarkManager.shared.copyBundleDocumentsToDocumentsFolder()
        }

        #if os(macOS)
        // Start the document open/save panels in the last document folder,
        // rather than wherever the last snapshot/image panel left off.
        ScopeState.seedDocumentPanelDirectory()
        #endif
    }
    
    static var scopeTemplateNamesAndIndexes: [ScopeTypeNameAndIndex] = {
        return scopeTemplates.map { ScopeTypeNameAndIndex(title: $0.name, index: $0.index) }
    }()

    /*
     static var scopeTemplateNamesAndIndexes: [(title: String, index: Int)] = {
         return scopeTemplates.map { (title: $0.name, index: $0.index) }
     }()

     */
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
//                .focusable()
                .focusedSceneObject(configuration.document.scopeState)
        }
        .defaultSize(width: 1800, height: 1125)
        .commands {
            ScopeWorksCommands()
            #if os(macOS)
            CommandGroup(replacing: CommandGroupPlacement.appInfo) {
                Button(action: {
                    // Open the "about" window
                    ScopeWorks2App.openWindow(id: "about")
                }, label: {
                    Text("About ScopeWorks")
                })
            }
            #endif
        }
        #if os(macOS)

            // Note the id "about" here
            Window("About ScopeWorks", id: "about") {
                Text(AboutView.aboutString)
            }
        #endif

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
            SettingsView(doneButtonAction: {} )
        }
#endif
    }


}
