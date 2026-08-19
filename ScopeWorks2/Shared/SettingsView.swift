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
    case savedAspects
}


struct SettingsView: View {
    
    @State private var showCustomAspectEditor: Bool = false
    @State private var isEditing: Bool = false
    
    @State private var width: Double = 1920

    @State private var height: Double = 1080
    @State private var multiplier = 1
    
    @State private var widthString: String = ""
    @State private var heightString: String = ""
    @State private var multiplierString: String = ""
    
    static func saveCustomAspectRatiosToUserDefaults() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let savedAspectsJSON = try encoder.encode(customAspectRatios)
            UserDefaults.standard.set(savedAspectsJSON, forKey: UserDefaultsKeys.savedAspects.rawValue)
        } catch {
            print("Eroror \(error.localizedDescription) encoding custom aspect ratios")
        }
        NotificationCenter.default.post(name: displaysChangedNotification, object: nil)
    }
    
    static func saveCustomAspectRatio(_ ratio: AspectRatio) {
        var ratio = ratio
        ratio.index = allAspectRatios().count
        customAspectRatios.append(ratio)
        saveCustomAspectRatiosToUserDefaults()
    }
    
    static var customAspectRatios: [AspectRatio] = []
    static let defaultAspectRatios: [AspectRatio] = [
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
            isCropForTiling: false),
        AspectRatio(
            title:  "14\" MBP",
            width:  756,
            height: 491,
            defaultMultiplier: 4,
            index: 7,
            isCropForTiling: false),
        AspectRatio(
            title:  "16\" MBP",
            width:  1728,
            height: 1117,
            defaultMultiplier: 2,
            index: 8,
            isCropForTiling: false),
        
        AspectRatio(
            title:  "iPad Pro 13\" (gen 7-8)",
            width:  4,
            height: 3,
            defaultMultiplier: 688,
            index: 9,
            isCropForTiling: false),


        AspectRatio(
            title:  "iPad 11\" (gen 7-8)",
            width:  605,
            height: 417,
            defaultMultiplier: 4,
            index: 10,
            isCropForTiling: false),
        
        AspectRatio(
            title:  "iPad 11\" (gen 3-5)",
            width:  199,
            height: 139,
            defaultMultiplier: 4,
            index: 11,
            isCropForTiling: false),
        
        AspectRatio(
            title:  "iPad Pro/Air 12.9\"/13\"",
            width:  683,
            height: 512,
            defaultMultiplier: 4,
            index: 12,
            isCropForTiling: false),
    ]
    
    /// Returns saved aspect ratios plus any unique ratios from connected displays.
    static func allAspectRatios() -> [AspectRatio] {
        var ratios = defaultAspectRatios

        let displays = ExternalDisplayManager.availableDisplays
        for display in displays {
            guard let aspect = display.aspect else { continue }
            if !ratios.contains(where: { $0.width == aspect.width && $0.height == aspect.height && aspect.multiplier == CGFloat($0.defaultMultiplier)}) {
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
        var editedCustomAspectRatios: [AspectRatio] = []
        for var aCustomAspect in customAspectRatios {
            aCustomAspect.index = ratios.count
            editedCustomAspectRatios.append(aCustomAspect)
            ratios.append(aCustomAspect)
        }
        self.customAspectRatios = editedCustomAspectRatios
        return ratios
    }
    
    @State var allAsepectRatios: [AspectRatio] = SettingsView.defaultAspectRatios

    var selectedAspectRatioIndex: Int = 0
    @State var selectedAspectRatio: AspectRatio {
        didSet {
            print("In selectedAspectRatio.didSet. New value = \(String(describing: selectedAspectRatio)). old value = \(String(describing: oldValue))")
            width = selectedAspectRatio.width
            height = selectedAspectRatio.height
            
            if width < 1 || height < 1 {
                widthString = String(format: "%.2f", width)
                heightString = String(format: "%.2f", height)

            } else {
                widthString = "\(Int(width))"
                heightString = "\(Int(height))"
            }            
            multiplier = selectedAspectRatio.defaultMultiplier
            multiplierString = "\(multiplier)"
        }
    }

    func updateAspectRatios() {
        allAsepectRatios = SettingsView.allAspectRatios()

    }
   
    func doInitSetup() {
        let defaults = UserDefaults.standard
        if let savedAspectsJSON = defaults.value(forKey: UserDefaultsKeys.savedAspects.rawValue) as? Data {
            do {
                let savedAspects = try JSONDecoder().decode([AspectRatio].self, from: savedAspectsJSON)
                SettingsView.customAspectRatios = savedAspects
            } catch {
                print("Error \(error.localizedDescription) trying to decode saved aspect ratios.")
            }
        }
        updateAspectRatios()
        if let selected = allAsepectRatios.first(where: {$0.index == selectedAspectRatioIndex}) {
            self.selectedAspectRatio = selected
        } else {
            print("Can't find aspect ratio with index: \(selectedAspectRatioIndex)")
        }
    }
    
    init(selectedAspectRatioIndex: Int, doneButtonAction: @escaping () -> Void) {
        self.doneButtonAction = doneButtonAction
        let snapshotFileType = UserDefaults.standard.integer(forKey: UserDefaultsKeys.snapshotFileType.rawValue)
        self.snapshotFileType = snapshotFileType
        self.selection = snapshotFileType
        self.selectedAspectRatio = SettingsView.allAspectRatios().first(where: { $0.index == 5 })!

//        self.selectedAspectRatio =         AspectRatio(
//            title: "16:9",
//            width: 16,
//            height: 9,
//            defaultMultiplier: 120,
//            index: 5,
//            isCropForTiling: false)
        self.selectedAspectRatioIndex = selectedAspectRatioIndex
        doInitSetup()
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
    
    #if os(macOS)
        let aspectRatioTitleWidth: CGFloat = 80
    #else
        let aspectRatioTitleWidth: CGFloat = 120
    #endif


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
                    HStack(spacing: 20) {
                        VStack {
                            Text(" ")
                            HStack {
                                Text("Aspect ratio:")
                                    .frame(minWidth: aspectRatioTitleWidth, alignment: .leading)
                                    .padding(.leading, snapshotTypeTitleLeading)
                                Picker("", selection: $selectedAspectRatio) {
                                    ForEach(allAsepectRatios) { aspectRatio in
                                        Text("\(aspectRatio.title)")
                                            .border(.blue, width: 2)
                                            .tag(aspectRatio, includeOptional: true)
                                            .frame(minWidth: 250, alignment: .leading)
                                    }
                                }
                                .frame(minWidth: 250)
                            }
                        }
                        .onChange(of: selectedAspectRatio) {
                            self.selectedAspectRatio = selectedAspectRatio
                            //isEditing = selectedAspectRatio.index == allAsepectRatios.count - 1
                            
                            print("selectedAspectRatio  changed to \(selectedAspectRatio). Posting notification.")
                            NotificationCenter.default.post(name: defaultAspectRatioChangedNotification, object: nil, userInfo: ["selectedAspectRatio": selectedAspectRatio])
                        }
                        VStack {
                            Text("Width")
                                .frame(minWidth: 60, alignment: .leading)
                                .multilineTextAlignment(.leading)


                            Text(widthString)
                                .frame(minWidth: 60, alignment: .leading)
                        }
                        VStack {
                            Text("Height")
                                .frame(minWidth: 60, alignment: .leading)
                                .multilineTextAlignment(.leading)

                            Text(heightString)
                                .frame(minWidth: 60, alignment: .leading)
                        }
                        VStack {
                            Text("Multiplier")
                                .frame(minWidth: 60, alignment: .leading)
                                .multilineTextAlignment(.leading)

                            Text(multiplierString)
                                .frame(minWidth: 60, alignment: .leading)
                        }

                        VStack {
                            Text("Pixel width")
                                .frame(minWidth: 60, alignment: .leading)
                                .multilineTextAlignment(.leading)

                            Text(String(Int(width * Double(multiplier))))
                                .frame(minWidth: 60, alignment: .leading)
                        }
                        VStack {
                            Text("Pixel height")
                                .frame(minWidth: 60, alignment: .leading)
                                .multilineTextAlignment(.leading)

                            Text(String(Int(height * Double(multiplier))))
                                .frame(minWidth: 60, alignment: .leading)
                        }

                    }
                    .onAppear() {
                        updateAspectRatios()
                        guard let selected = allAsepectRatios.first(where: { $0.index == selectedAspectRatioIndex }) else {
                            fatalError("unable to find selected aspect ratio with index \(selectedAspectRatioIndex)")
                        }
                        
                        self.selectedAspectRatio = selected
                    }
                    HStack(spacing: 50) {
                        Button("Add custom aspect ratio") {
                            showCustomAspectEditor = true
                        }
                        .padding(.leading, 10)
                        if selectedAspectRatio.index >= allAsepectRatios.count - SettingsView.customAspectRatios.count {
                            Button("Delete custom aspect ratio") {
                                var customAspectRatios = SettingsView.customAspectRatios
                                let nonCustomAspectCount = allAsepectRatios.count - SettingsView.customAspectRatios.count
                                guard  let index = customAspectRatios.firstIndex(of: selectedAspectRatio) else {
                                    print("Can't find aspect ratio to remove. Exiting")
                                    return
                                }
                                customAspectRatios.remove(at:index)
                                for (index, var aCustomAspect) in customAspectRatios.enumerated() {
                                    aCustomAspect.index = index + nonCustomAspectCount
                                    customAspectRatios[index] = aCustomAspect
                                }
                                SettingsView.customAspectRatios = customAspectRatios
                                SettingsView.saveCustomAspectRatiosToUserDefaults()
                                updateAspectRatios()
                                selectedAspectRatio = allAsepectRatios.last!
                            }
                            .padding(.leading, 10)

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
        .sheet(isPresented: $showCustomAspectEditor) {
            CustomAspectRatioEditor(dismissClosure: { showCustomAspectEditor = false })
                .frame(minWidth: 800)
        }
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
