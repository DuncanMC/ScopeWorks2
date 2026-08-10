//
//  SettingsView.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 7/3/26.
//

import SwiftUI
import UniformTypeIdentifiers
import simd


let defaultAspectRatioChangedNotification = Notification.Name("defaultAspectRatioChangedNotification")


enum SnapshotFormat: String, CaseIterable {
    case JPEG, PNG, TIFF
    
    var fileType: UTType? {
        return UTType(filenameExtension: self.rawValue)
    }
}

var settingsChangedNotification = Notification.Name(rawValue: "settingsChanged")


enum UserDefaultsKeys: String {
    case snapshotFileType
    case folderSetupComplete
    case lastUsedImageDirectoryBookmark
    case lastUsedExportDirectoryBookmark
    case lastUsedDocumentDirectoryPath
    case includeKaleidoscopeInfoInSavedImages
}


struct SettingsView: View {
    
    
    static let savedAspectRatios: [AspectRatio] = [
        AspectRatio(
            title: "Crop for Tiling",
            width: 0.6,
            height: sqrt(3)/5.0,
            defaultMultiplier: 3200,
            index: 0,
            isCropForTiling: true),
        AspectRatio(
            title: "Square",
            width:  1,
            height: 1,
            defaultMultiplier: 1920,
            index: 1,
            isCropForTiling: false),
        AspectRatio(
            title: "3:2",
            width:  3,
            height: 2,
            defaultMultiplier: 640,
            index: 2,
            isCropForTiling: false),
        AspectRatio(
            title: "4:3",
            width:  4,
            height: 3,
            defaultMultiplier: 480,
            index: 3,
            isCropForTiling: false),
        AspectRatio(
            title: "8:10",
            width:  5,
            height: 4,
            defaultMultiplier: 384,
            index: 4,
            isCropForTiling: false),
        AspectRatio(
            title: "16:9",
            width: 16,
            height: 9,
            defaultMultiplier: 120,
            index: 5,
            isCropForTiling: false),
        AspectRatio(
            title:  "8:5",
            width:  8,
            height: 5,
            defaultMultiplier: 240,
            index: 6,
            isCropForTiling: false)
    ]
    
    /// Returns saved aspect ratios plus any unique ratios from connected displays.
    static func allAspectRatios() -> [AspectRatio] {
        var ratios = savedAspectRatios
        let displays = ExternalDisplayManager.availableDisplays
        for display in displays {
            guard let aspect = display.aspect else { continue }
            if !ratios.contains(where: { $0.width == aspect.width && $0.height == aspect.height }) {
                let name = "\(display.name) (\(Int(aspect.width)):\(Int(aspect.height)))"
                ratios.append(AspectRatio(
                    title: name,
                    width: aspect.width,
                    height: aspect.height,
                    defaultMultiplier: Int(aspect.multiplier) * Int(display.scale),
                    index: ratios.count,
                    isCropForTiling: false))
            }
        }
        return ratios
    }
    
    @State var allAsepectRatios: [AspectRatio] = SettingsView.savedAspectRatios

    @State var selectedAspectRatio: AspectRatio {
        didSet {
            print("New value = \(selectedAspectRatio). old value = \(oldValue)")
        }
    }

    func updateAspectRatios() {
        allAsepectRatios = SettingsView.allAspectRatios()
    }
    
    init(selectedAspectRatio: AspectRatio, doneButtonAction: @escaping () -> Void) {
        self.doneButtonAction = doneButtonAction
        let snapshotFileType = UserDefaults.standard.integer(forKey: UserDefaultsKeys.snapshotFileType.rawValue)
        self.snapshotFileType = snapshotFileType
        self.selection = snapshotFileType
        self.allAsepectRatios = SettingsView.savedAspectRatios
        self.selectedAspectRatio = selectedAspectRatio
        updateAspectRatios()

    }
    
    var doneButtonAction: () -> Void
    @State private var showingFolderSetup = false
    
    
    @AppStorage(UserDefaultsKeys.snapshotFileType.rawValue) var snapshotFileType: Int = UserDefaults.standard.integer(forKey: UserDefaultsKeys.snapshotFileType.rawValue)

    @AppStorage(UserDefaultsKeys.includeKaleidoscopeInfoInSavedImages.rawValue)
    var includeKaleidoscopeInfo: Bool = true


    var snapshotTypePickerLeading: CGFloat {
        #if os(macOS)
            return 14
        #else
            return 45
        #endif
    }

    var snapshotTypeTitleLeading: CGFloat {
        #if os(macOS)
            return 12
        #else
            return 7
        #endif
    }

    @State var selection: Int
    
    
    var options: [(title: String, index: Int)] = {
        SnapshotFormat.allCases.enumerated().map {
            ($0.element.rawValue, $0.offset)
        }
    }()

    var body: some View {
        ZStack {
            VStack(alignment: .center) {
                #if os(iOS)
                    Text("Settings")
                        .padding(.top, 20)
                #endif
                Spacer()
                VStack(alignment: .leading, spacing: 30) {
                    Text("Snapshots")
                        .font(.headline)
                        .frame(alignment: .leading)
                        .padding(.leading, 13)
                    HStack {
                        Text("Snapshot filetype")
                            .frame(minWidth: 120, alignment: .leading)
                            .padding(.leading, snapshotTypeTitleLeading)
                        Picker("", selection: $selection) {
                            ForEach(options, id: \.self.index) { option in
                                Text("\(option.title)")
                                    .frame(minWidth: 150, alignment: .leading)
                            }
                        }
                        .onChange(of: selection) {
                            snapshotFileType = selection
                            UserDefaults.standard.set(snapshotFileType, forKey: UserDefaultsKeys.snapshotFileType.rawValue)
                            let center = NotificationCenter.default
                            let userInfo = [UserDefaultsKeys.snapshotFileType.rawValue:  snapshotFileType]
                            center.post(name: settingsChangedNotification, object: nil, userInfo: userInfo)
                        }
                        .labelsHidden()
                        .frame(minWidth: 150, alignment: .leading)
                        .padding(.leading, snapshotTypePickerLeading)
                        Spacer()
                    }
                        .frame(maxHeight: 25)
                        .frame(minWidth: 250)

                    Toggle("Include kaleidoscope info in saved images",
                           isOn: $includeKaleidoscopeInfo)
                        .padding(.leading, snapshotTypeTitleLeading)
                        .padding(.trailing, 50)

                    Divider()
                        .padding(.horizontal, 20)

                    Text("Image/Video aspect ratio")
                        .font(.headline)
                        .frame(alignment: .leading)
                        .padding(.leading, 13)
                    //-----------------------
                    HStack {
                        Text("Aspect ratio")
                            .frame(minWidth: 120, alignment: .leading)
                            .padding(.leading, snapshotTypeTitleLeading)
                        Picker("", selection: $selectedAspectRatio) {
                            ForEach(allAsepectRatios) { aspectRatio in
                                Text("\(aspectRatio.title)").tag(aspectRatio.index)
                                    .frame(minWidth: 150, alignment: .leading)
                            }
                        }
                        .onChange(of: selectedAspectRatio) {
                            print("selectedAspectRatio  changed to \(selectedAspectRatio). Posting notification.")
                            NotificationCenter.default.post(name: defaultAspectRatioChangedNotification, object: nil, userInfo: ["selectedAspectRatio": selectedAspectRatio])
                        }
                    }

//-----------------------
                    Divider()
                        .padding(.horizontal, 20)

                    Text("Folders")
                        .font(.headline)
                        .frame(alignment: .leading)
                        .padding(.leading, 13)

                    VStack(alignment: .leading, spacing: 8) {
                        folderStatusRow(label: "Source Images", url: FolderBookmarkManager.shared.sourceImagesURL)
                        folderStatusRow(label: "Documents", url: FolderBookmarkManager.shared.documentsURL)
                        folderStatusRow(label: "Snapshots", url: FolderBookmarkManager.shared.snapshotsURL)
                    }
                    .padding(.leading, snapshotTypeTitleLeading)

                    Button("Re-configure Folders...") {
                        showingFolderSetup = true
                    }
                    .padding(.leading, snapshotTypeTitleLeading)
                }
                Spacer()
                Spacer()
            }
#if os(iOS)
            VStack {
                Spacer()
                Button("Done") {
                    doneButtonAction()
                }
                .padding(.bottom, 20)
            }
#endif

        }
        .onAppear() {
            updateAspectRatios()
        }
        .onReceive(NotificationCenter.default.publisher(for: displaysChangedNotification)) { notification in
            updateAspectRatios()
            }
        #if os(iOS)
        .fullScreenCover(isPresented: $showingFolderSetup) {
            FirstLaunchSetupView(
                folderManager: FolderBookmarkManager.shared,
                onComplete: {
                    showingFolderSetup = false
                }
            )
        }
        #else
        .sheet(isPresented: $showingFolderSetup) {
            FirstLaunchSetupView(
                folderManager: FolderBookmarkManager.shared,
                onComplete: {
                    showingFolderSetup = false
                }
            )
            .frame(minWidth: 500, minHeight: 400)
        }
        #endif
    }

    private func folderStatusRow(label: String, url: URL?) -> some View {
        HStack {
            Text(label)
                .frame(minWidth: 120, alignment: .leading)
            if let url = url {
                Text(url.lastPathComponent)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Not configured")
                    .foregroundStyle(.red)
            }
        }
    }
}

//#Preview {
//    SettingsView()
//}
