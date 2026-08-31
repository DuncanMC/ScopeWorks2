import SwiftUI
import Combine
import simd
import PhotosUI

enum ActiveModal: Identifiable {
    case imageSource
    case settings
    case help
    case about
    
    var id: String {
        switch self {
        case .imageSource: "imageSource"
        case .settings: "settings"
        case .help: "help"
        case .about: "about"
        }
    }
}

struct ContentView: View {
    
    @Namespace private var ns

    @AppStorage("folderSetupComplete") private var folderSetupComplete = false
    @State private var showRelocationAlert = false
    @State private var showRelocationPicker = false
    #if os(iOS)
    @State private var relocationPickerDelegate: RelocationFilePickerDelegate?
    #endif
    

    var imageSourceLeading: CGFloat {
        #if os(macOS)
            return 7
        #else
            return 10
        #endif
    }

    var polygonSidesLeading: CGFloat {
        #if os(macOS)
            return 12
        #else
            return 7
        #endif
    }
    
    var splitPolygonTrianglesLeading: CGFloat {
#if os(macOS)
    return 25
#else
    return 13
#endif
    }
    
    var kaleidoscopeTypeLeading: CGFloat {
    #if os(macOS)
        return 0
    #else
        return 0
        
#endif
    }
    
    var reverseAnimationLeading: CGFloat {
        #if os(macOS)
            return 61
        #else
            return 110
        #endif
    }

    var backgroundColorLeading: CGFloat {
        #if os(macOS)
            return 17
        #else
            return 12
        #endif
    }

    let sliderWidth = 350.0
    @ObservedObject var scopeState: ScopeState
    @StateObject private var externalDisplayViewManager: ExternalDisplayViewManager
    @Environment(\.undoManager) var undoManager
    #if os(macOS)
    @Environment(\.documentConfiguration) private var documentConfiguration
    #endif

    init(scopeState: ScopeState) {
        self.scopeState = scopeState
        if let existing = scopeState.externalDisplayViewManager {
            _externalDisplayViewManager = StateObject(wrappedValue: existing)
        } else {
            let manager = ExternalDisplayViewManager(scopeState: scopeState)
            scopeState.externalDisplayViewManager = manager
            scopeState.updateDisplays()

            _externalDisplayViewManager = StateObject(wrappedValue: manager)
        }
    }
    
    let zoomDetents: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
    let radiusDetents: [Double] = [0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
    
    var rotationString: String {
        String(format:"%.02f", scopeState.rotationSpeed)
    }
    var zoomString: String {
        String(format:"%.02f", scopeState.zoom/2.0)
    }
    
    var radiusString: String {
        String(format:"%.02f", scopeState.radiusScale)
    }
    
    //
    
    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 0
        formatter.numberStyle = .none
        formatter.paddingCharacter = " "
        formatter.paddingPosition = .afterPrefix
        formatter.minimum = 4
        formatter.maximum = 100
        return formatter
    }()
    
    enum FocusedField: Hashable {
        case textField
        case sourceImageView
    }

//    @FocusState private var sourceImageFocused: Bool
    @FocusState private var focusedField: FocusedField?

    //@FocusState private var isFocused
    @State private var selection: TextSelection?
    @State private var site = ""
    
    
    @State var polygonSidesString = ""
    
    @State private var isDragging = false
    @State private var isRotating = false
    @State private var isFullScreen = false
    
    
    var rotateGesture: some Gesture {
        RotateGesture()
            .onChanged { value in
                if !isRotating {
                    //print("begin rotate gesture.")
                    isRotating = true
                }
                
                scopeState.rotateTriangleByAngle(Float(-value.rotation.radians))
            }
            .onEnded { _ in
                //print("rotateGesture ended.")
                isRotating = false
                isDragging = false
                scopeState.previousRotation = nil
                scopeState.lastDragLocation = nil
                
            }
    }
    
    var tapGesture: some Gesture {
        TapGesture(count: 1)
            .onEnded { _ in
                Task { @MainActor in
                    focusedField = .sourceImageView
                }
            }
    }
    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                var  flags: UInt = 0
#if os(macOS)
                flags = NSEvent.modifierFlags.rawValue
#endif
                
                if !isDragging {
                    //print("Begin dragging in view.")
                    if let target = scopeState.getDragLocation( value.startLocation) {
                        //                        print("\nUser tapped in \(target.dragLocation.rawValue)\n")
                        scopeState.draggingState = target.dragLocation
                        scopeState.lastDragLocation = value.startLocation
                        self.isDragging = true
                    } else {
                        //print("\nUser did not tap in a known location\n")
                    }
                    
                } else {
                    //print("continuing drag.")
                    scopeState.handleDragging(value: value, flags: flags)
                }
            }
            .onEnded { value in
                self.isDragging = false
                isRotating = false
                scopeState.lastDragLocation = nil
                //                let draggingStateString = scopeState.draggingState?.rawValue ?? "nil"
                //print("\ndragGesture ended. scopeState.draggingState = \(draggingStateString). texAspect = \(scopeState.texAspect).")
                //print("rotationCenter = \(scopeState.rotationCenter.myDescription)")
                //print("TrianglePoints = \n\(scopeState.trianglePoints)")
            }
    }
    
    var rotateOrDragGesture: some Gesture {
        return ExclusiveGesture(rotateGesture, dragGesture)
    }
    
    var toggleAlignment: Alignment {
#if os(macOS)
        return .leading
#else
        return .trailing
#endif
        
    }
    
    private func label(for value: Double) -> some View {
        Text(String(format: "%.2f", value))
    }
    
#if os(iOS)
    @State private var image: UIImage? = nil
#elseif os(macOS)
    @State private var image: NSImage? = nil
#endif

    // MARK: - Polygon sides field
    @ViewBuilder
    private var polygonSidesField: some View {
        LabeledContent(content: {
            TextField("",
                      text: $polygonSidesString,
                      onEditingChanged: { isEditing in
            },
                      onCommit: {
                guard let value = Self.numberFormatter.number(from: polygonSidesString) else {
                    Task { @MainActor in
                        self.polygonSidesString = "\(scopeState.polygonSides)"
                    }
                    return
                }
                scopeState.polygonSides = value.intValue
                focusedField = .sourceImageView
//                isFocused = false
            }

            )
            .padding(.leading, 0)
            .textFieldStyle(.customRoundedBorderTextFieldStyle(borderColor: .gray))
            .frame(minWidth: 35, maxWidth: 35)
           // .focused($focusedField, equals: .textField)
            .onAppear() {
#if os(macOS)
                Task { @MainActor in
                    let _ = NSApp.keyWindow?.makeFirstResponder(nil)
                }
#endif
            }

            .onChange(of: focusedField) {
                if focusedField == .textField {
                    Task { @MainActor in
#if os(macOS)
                        NSApplication.shared.tryToPerform(#selector(NSResponder.selectAll(_:)), with: nil)
#else
                        UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
#endif
                    }
                    selection = .init(range: site.startIndex..<site.endIndex)
                }
            }
            .onAppear() {
                polygonSidesString = "\(scopeState.polygonSides)"
            }
        },
                       label: {
            Text("Polygon sides")
                .frame(minWidth: 50, alignment: .leading)
            
        })
        .padding(.leading, polygonSidesLeading)
        #if os(iOS) || os(iPadOS)
            .frame(maxWidth: 225)
        #endif
    }

    // MARK: - Controls
    @ViewBuilder
    private var controlsView: some View {
        // to hide controls in fullscreen mode, change if statement to read
        // "if scopeState.showControls && !isFullScreen"
        if scopeState.showControls {
            HStack(spacing: 30) {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // External display picker
                    if !$scopeState.availableDisplays.isEmpty {
                        HStack {
                            Text("Fullscreen Display:")
#if os(macOS)
                                .padding(.leading, 12)
#else
                                .padding(.leading, 5)
#endif
                            Picker("", selection: $scopeState.chosenDisplayID) {
                                ForEach(scopeState.availableDisplays) { display in
                                    Text(display.name).tag(Optional(display.id))
                                }
                            }
                            .frame(minWidth: 200)
#if os(macOS)
                            .padding(.leading, 26)
#endif
                            
                        }
                    }
                    
                    //Kaleidoscope type picker
                    ScopeTypePicker(title: "Kaleidoscope Type:", options: ScopeWorks2App.scopeTemplateNamesAndIndexes, selection: $scopeState.selectedScopeType)
                        .frame(width: 460)
                    
                        .onChange(of: scopeState.selectedScopeType) { oldValue, newValue in
                            //print("selectedScopeType = \(newValue)")
                            if !scopeState.isPolygonScope {
                                scopeState.splitTriangle = false
                            }
                        }
                        .padding(.leading, kaleidoscopeTypeLeading)
                    
                    HStack {
                        //Polygon sides
                        polygonSidesField
                        
                        Toggle("Split polygon triangles", isOn: $scopeState.splitTriangle)
                            .padding(.leading, splitPolygonTrianglesLeading)
                            .disabled(!scopeState.isPolygonScope)
                    }
                    HStack {
                        //Image source button
                        Button("Image source") {
                            scopeState.presentedModal = .imageSource
                        }
                        #if os(macOS)
                            .padding(.leading, 0)
                            .padding(.trailing, 30)
                        #else
                            .padding(.leading, 7)
                            .padding(.trailing, 20)
                        #endif
                        
                        //background color well
                        ColorPicker("Background color", selection: $scopeState.backgroundColor)
                            .frame(minWidth: 200)
                            .padding(.leading, backgroundColorLeading)
                    }
                    .padding(.leading, 0)

                }
                
                .padding(.leading, 10)
                // MARK: - Sliders
                VStack(alignment: .leading, spacing: 20) {
                    // Rotation speed
                    HStack {
                        Text("Rotation speed: \(rotationString)")
                            .frame(minWidth: 200, alignment: .leading)
                        //                                    .border(.black, width: 1)
                        Slider(value: $scopeState.rotationSpeed, in: -15.0 ... 15.0, step: 1.0)
                            .frame(width: sliderWidth )
                            .frame(minWidth: 150 )
                    }
                    
                    // Zoom
                    HStack {
                        Text("Zoom: \(zoomString)")
                            .frame(minWidth: 200, alignment: .leading)
                        //                                    .border(.black, width: 1)
                        
                        Slider(value: $scopeState.zoom, in: 1.16 ... 5.0)
                            .frame(width: sliderWidth )
                            .frame(minWidth: 150 )
                        
                    }
                    // Radius
                    HStack {
                        Text("Radius: \(radiusString)")
                            .frame(minWidth: 200, alignment: .leading)
                        Slider(value: $scopeState.radiusScale, in: 0.5...1.0)
                            .frame(width: sliderWidth )
                            .frame(minWidth: 150 )
                            .disabled(scopeState.selectedScopeType != .polygonGrid)

                    }
                    Text(scopeState.imageSourceDescription)
                        .frame(height: 25)
                        .onTapGesture {
                            if scopeState.imageSourceMode == .staticImage,
                               let fileURL = scopeState.imageSourceInfo.fullURL {
                                let fileName = fileURL.lastPathComponent
                                #if os(macOS)
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(fileName, forType: .string)
                                scopeState.showFileInFinder(url: fileURL)
                                #else
                                    UIPasteboard.general.string = fileName
                                #endif
                            }
                        }
                }
                Spacer()
            }
            .transition(.move(edge: .bottom))

            .padding(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
            #if os(iOS)
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        scopeState.presentedModal = .settings
                    } label:  {
                        Image(systemName: "gear")
                            .resizable(resizingMode: .stretch)
                            .frame(width: 30, height: 30)
                    }
                    .padding([.trailing, .bottom])
                    .padding(.top, 25)
                    .buttonStyle(.borderless)
                }
            #endif
        }
    }

    var body: some View {
        VStack {
            HStack {
                // to hide source image in fullscreen mode, change if statement to read
                // "if scopeState.showSourceImage && !isFullScreen"
                if scopeState.showSourceImage {
                    SourceImageViewRepresentable(scopeState: scopeState)
                        .gesture(tapGesture
                            .exclusively(before: dragGesture
                                .exclusively(before: rotateGesture)
                            )
                        )
                        .focusable(interactions: .edit)
                        .focused($focusedField, equals: .sourceImageView)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white)
                        .aspectRatio(scopeState.texSize, contentMode: .fit)
                        .transition(.move(edge: .leading))
                        .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow], phases: [.down, .repeat]) { press in
                            let isShifted =  press.modifiers.contains(.shift)
                            if press.modifiers.contains(.option)  {
                                return .ignored
                            }
                            scopeState.handleArrowKey(press, isShifted: isShifted)
                            return .handled
                        }
                }
                
                ZStack {
                    #if os(iOS) || os(iPadOS)
                        ScopeViewRepresentable(
                            scopeState: scopeState,
                            allowImageExport: true,
                            isMainDocumentScopeView: true,
                        )
                        .help("Tap with two fingers to take a snapshot")
                        .gesture(TwoFingerTapGesture {
                            print("Two finger tap detected")
                            scopeState.handleSnapshot(isFullScreenView: false)
                        })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white)
                    #else
                    ScopeViewRepresentable(
                        scopeState: scopeState,
                        allowImageExport: true,
                        isMainDocumentScopeView: true,
                        )

                    .help("Tap to take a snapshot")

                        .onTapGesture {
                            print("Tap gesture recognized")
                            scopeState.handleSnapshot(isFullScreenView: false)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white)
                    #endif
                    VStack {
                        Spacer()
                            .frame(maxHeight: .infinity)
                        HStack(alignment: .center) {
                            Spacer()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    if let recorder = scopeState.activeRecorder {
                        VStack {
                            VideoRecordingControlsView(recorder: recorder) {
                                #if os(iOS)
                                scopeState.completedVideoURL = recorder.outputURL
                                #endif
                                scopeState.activeRecorder = nil
                            }
                            .padding(.top, 10)
                            Spacer()
                        }
                    }
                }
            }
            controlsView
        }
        // Animate the controls sliding in/out from the bottom (paired with the
        // .move(edge: .bottom) transition on controlsView). Attaching the
        // animation to the value means it fires no matter where the toggle
        // comes from (menu command, keyboard shortcut, or NSEvent monitor).
        .animation(.easeInOut(duration: 0.2), value: scopeState.showControls)
        .animation(.easeInOut(duration: 0.2), value: scopeState.showSourceImage)
        #if os(macOS)
        // Remember the folder containing this document whenever it's opened or
        // saved, so the next document open/save panel starts there. Also track
        // the URL on the state (for post-save Finder icon updates) and apply
        // the icon from the package's thumbnail when the URL appears (open,
        // first save, save-as).
        .onChange(of: documentConfiguration?.fileURL, initial: true) { _, newURL in
            scopeState.documentFileURL = newURL
            if let newURL {
                // Legacy flat .ksp2 files must not be edited in place. This
                // hook is the one macOS choke point that sees every open path
                // (Finder, File > Open, Open Recent) — the document machinery
                // claims readable types before the app delegate's
                // application(_:open:) is ever called. Close the in-place
                // document immediately (before it can autosave the package
                // format over the flat file) and reopen it as an untitled
                // "<name> (converted)" document.
                if MetadataImport.isLegacyFlatDocument(newURL) {
                    DispatchQueue.main.async {
                        NSDocumentController.shared.document(for: newURL)?.close()
                        MetadataImport.openConvertedLegacyDocument(at: newURL)
                    }
                    return
                }
                ScopeState.recordDocumentDirectory(forDocumentAt: newURL)
                //ScopeDocument.applyFinderIcon(forDocumentAt: newURL)
            }
        }
        #endif

        .sheet(item: $scopeState.presentedModal) { modalType in
            switch modalType {
            case .settings:
                SettingsView(doneButtonAction: {
                        scopeState.presentedModal = nil
                    },
                )
                .frame(minWidth: 1000)
            case .imageSource:
                ImageSouceView(scopeState: scopeState,
                               dismissClosure: {
                    scopeState.presentedModal = nil
                })
            case .help:
                HelpView()
                    .frame(maxWidth: .infinity)
            case .about:
                AboutView()
                    .frame(maxWidth: 1000)
                    #if os (iOS)
                        .navigationTransition(.zoom(sourceID: 0, in: ns))
                    #else
                        .navigationTransition(.automatic)
                    #endif
                    .presentationSizing(.fitted)
                

            }
        }
        .sheet(isPresented: Binding(
            get: { !folderSetupComplete },
            set: { if !$0 { folderSetupComplete = true } }
        )) {
            FirstLaunchSetupView(
                folderManager: FolderBookmarkManager.shared,
                onComplete: { folderSetupComplete = true }
            )
            .interactiveDismissDisabled()
            #if os(macOS)
            .frame(minWidth: 500, minHeight: 400)
            #endif
        }
        #if os(iOS)
        .sheet(isPresented: $scopeState.showExportImageSheet) {
            if let settings = scopeState.exportSettingsState {
                ExportImageSheetView(settings: settings, scopeState: scopeState)
            }
        }
        .sheet(isPresented: $scopeState.showRecordVideoSheet) {
            if let settings = scopeState.exportSettingsState {
                RecordVideoSheetView(settings: settings, scopeState: scopeState)
            }
        }
        .sheet(isPresented: Binding(
            get: { scopeState.completedVideoURL != nil },
            set: { if !$0 { scopeState.completedVideoURL = nil } }
        )) {
            if let url = scopeState.completedVideoURL {
                ActivityViewController(activityItems: [url])
            }
        }
        #endif
        .alert("Image Not Found", isPresented: $showRelocationAlert) {
            Button("Locate...") {
                openRelocationPicker()
            }
            Button("Skip", role: .cancel) {
                scopeState.needsImageRelocation = false
                scopeState.relocatedImageCandidate = nil
            }
        } message: {
            if let candidate = scopeState.relocatedImageCandidate {
                Text("The source image '\(scopeState.imageSourceInfo.filename ?? "unknown")' was found in \(candidate.deletingLastPathComponent().lastPathComponent). Click Locate to open it.")
            } else {
                Text("The source image '\(scopeState.imageSourceInfo.filename ?? "unknown")' could not be found. Click Locate to find it.")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ScopeState.relocationReadyNotification)) { notification in
            if let state = notification.object as? ScopeState, state === scopeState {
                showRelocationAlert = true
            }
        }


#if os(iOS)
// MARK: hidden iOS menubar for keyboard shortcuts.
// return key = "↩"
//command key =  "⌘"
//option key = "⌥"

        .background {
            ScopeCommandButtons(scopeState: scopeState, alternateShortcutCommandsOnly: false)
        }
#else
        .background {
            ScopeCommandButtons(scopeState: scopeState, alternateShortcutCommandsOnly: true)
        }
#endif
        .focusedSceneObject(scopeState)
#if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { _ in
            isFullScreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { _ in
            isFullScreen = false
        }
#endif
        .onReceive(scopeState.objectWillChange) { _ in
            if !scopeState.isLoadingFromFile && !scopeState.animate && scopeState.imageSourceMode == .staticImage {
                undoManager?.registerUndo(withTarget: scopeState) { _ in }
            }
        }
        .onChange(of: scopeState.animate) { _, newValue in
            if !newValue && !scopeState.isLoadingFromFile {
                undoManager?.registerUndo(withTarget: scopeState) { _ in }
            }
        }
#if os(iOS)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Menu("File", systemImage: "doc") {
                    Button("Save Image as...") {
                        scopeState.saveImageAs()
                    }
                    Button("Create Video...") {
                        scopeState.recordVideo()
                    }
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu("Edit", systemImage: "scissors") {
                    Button("Undo  (⌘Z)") {
                        undoManager?.undo()
                    }
                    .disabled(!(undoManager?.canUndo ?? false))
                }
            }
            // MARK: - iOS menubar
            ToolbarItem(placement: .secondaryAction) {
                Menu("View Options", systemImage: "eye") {
                    ForEach(ScopeCommand.viewCommands) { command in
                        if command.isToggle, let kp = command.keyPath {
                            Toggle("\(command.label) (\(command.shortcutHint))",
                                   isOn: Binding(
                                       get: { scopeState[keyPath: kp] },
                                       set: { scopeState[keyPath: kp] = $0 }
                                   ))
                            .disabled(command.disableCommandClosure(scopeState))
                        } else {
                            Button("\(command.label) (\(command.shortcutHint))") {
                                command.performAction(on: scopeState)
                            }
                            .disabled(command.disableCommandClosure(scopeState))
                        }
                    }
                }
            }
            // Place help menu here
            ToolbarItem(placement: .secondaryAction) {
                Menu("Help", systemImage: "questionmark") {
                    
                    Button("ScopeWorks Help") {
                        scopeState.presentedModal = .help
                    }
                    Button("About ScopeWorks") {
                        print("About button tapped")
                        scopeState.presentedModal = .about
                    }
                }
            }

        }
#endif

    }
    
    // MARK: - Image relocation file picker
    
    private func openRelocationPicker() {
        let startDirectory: URL? = scopeState.relocatedImageCandidate?.deletingLastPathComponent()
            ?? FolderBookmarkManager.shared.sourceImagesURL
        
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .tiff, .heic].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.directoryURL = startDirectory
        panel.contentMinSize = NSSize(width: 800, height: 500)
        panel.message = "Select '\(scopeState.imageSourceInfo.filename ?? "the missing image")' to relink it"
        panel.prompt = "Open"
        
        if panel.runModal() == .OK, let url = panel.url {
            scopeState.applyRelocatedImage(url: url)
        }
        #else
        let types: [UTType] = [.jpeg, .png, .tiff, .heic].compactMap { $0 }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.allowsMultipleSelection = false
        picker.modalPresentationStyle = .fullScreen
        if let dir = startDirectory {
            picker.directoryURL = dir
        }
        
        let delegate = RelocationFilePickerDelegate()
        delegate.onPick = { [weak scopeState] url in
            scopeState?.applyRelocatedImage(url: url)
        }
        self.relocationPickerDelegate = delegate
        picker.delegate = delegate
        
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first,
           let rootVC = keyWindow.rootViewController {
            var presentingVC = rootVC
            while let presented = presentingVC.presentedViewController {
                presentingVC = presented
            }
            presentingVC.present(picker, animated: true)
        }
        #endif
    }

}

// MARK: - iOS Relocation File Picker Delegate
#if os(iOS)
class RelocationFilePickerDelegate: NSObject, UIDocumentPickerDelegate {
    var onPick: ((URL) -> Void)?
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        onPick?(url)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        onPick = nil
    }
}

// MARK: - iOS Export Image Sheet
/// Sheet content for image export. Observes the export settings so the Export
/// button's enabled state updates live as the user edits the dimensions.
struct ExportImageSheetView: View {
    @ObservedObject var settings: ExportSettingsState
    @ObservedObject var scopeState: ScopeState

    var body: some View {
        NavigationStack {
            ExportSettingsView(settings: settings, isForVideo: false)
                .navigationTitle("Export Image")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            scopeState.showExportImageSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Export") {
                            // Safety net — the button is disabled when the size is too large.
                            guard !settings.exceedsMaxTextureSize else { return }
                            scopeState.showExportImageSheet = false
                            guard let renderer = scopeState.documentRenderer,
                                  let filetype = settings.selectedFormat.fileType,
                                  let image = renderer.renderOffscreenImage(
                                      width: settings.exportWidth,
                                      height: settings.exportHeight,
                                      aspectRatio: settings.selectedAspectRatio
                                  ) else { return }
                            scopeState.showSavePanel(
                                image: image,
                                defaultFilename: "ScopeWorks image",
                                directoryURL: nil,
                                filetype: filetype
                            )
                        }
                        .disabled(settings.exceedsMaxTextureSize)
                    }
                }
        }
    }
}

// MARK: - iOS Record Video Sheet
/// Sheet content for video recording. Observes the export settings so the Start
/// Recording button's enabled state updates live as the user edits the dimensions.
struct RecordVideoSheetView: View {
    @ObservedObject var settings: ExportSettingsState
    @ObservedObject var scopeState: ScopeState

    var body: some View {
        NavigationStack {
            ExportSettingsView(settings: settings, isForVideo: true)
                .navigationTitle("Record Video")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            scopeState.showRecordVideoSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Start Recording") {
                            // Safety net — the button is disabled when the size is too large.
                            guard !settings.exceedsMaxVideoSize else { return }
                            scopeState.showRecordVideoSheet = false
                            guard let renderer = scopeState.documentRenderer else { return }
                            let tempURL = FileManager.default.temporaryDirectory
                                .appendingPathComponent("ScopeWorks recording.mov")
                            let recorder = VideoRecorder(
                                width: settings.exportWidth,
                                height: settings.exportHeight,
                                outputURL: tempURL,
                                renderer: renderer,
                                aspectRatio: settings.selectedAspectRatio
                            )
                            do {
                                try recorder.setup()
                                scopeState.activeRecorder = recorder
                            } catch {
                                print("Failed to set up video recorder: \(error)")
                            }
                        }
                        .disabled(settings.exceedsMaxVideoSize)
                    }
                }
        }
    }
}
#endif

struct PhotoPickerView: View {
    
    @State private var selectedItem: PhotosPickerItem?
    @ObservedObject var scopeState: ScopeState
    
    var dismissClosure: (() -> Void)

    
    var body: some View {
        #if os(macOS)
            Button("Select Image") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [UTType(filenameExtension: "jpg"),
                                             UTType(filenameExtension: "png"),
                                             UTType(filenameExtension: "tiff"),
                                             UTType(filenameExtension: "tif")].compactMap { $0 }
                
                panel.allowsMultipleSelection = false
                panel.canChooseFiles = true
                panel.canChooseDirectories = false
                if panel.runModal() == .OK,
                let url = panel.url {
                    scopeState.imageURL = url
                    do {
                        scopeState.bookmarkData = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil)
                        //                    scopeState.bookmarkData = createSecurityScopedBookmark(for: url)
                    } catch {
                        print("Error \(error) creating bookmarkl")
                    }
                    dismissClosure()
                    print("bookmarkData = \(String(describing: scopeState.bookmarkData))")
                    if let typeID = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier {
                        print("typeID = \(typeID)")
                        scopeState.isHEIC =  typeID == UTType.heic.identifier
                    }
                }
            }
        
        #else
        PhotosPicker("Select Image", selection: $selectedItem, matching: .images, photoLibrary: .shared())
                .onChange(of: selectedItem) {
                    Task { @MainActor in
                        if let newValue = selectedItem {
                            scopeState.isHEIC =  newValue.supportedContentTypes.contains(UTType.heic)
                            
                            let data = try? await newValue.loadTransferable(type: Data.self)
                            print("newValue = \(newValue)")
                            print("newValue.supportedContentTypes = \(newValue.supportedContentTypes)")
                            scopeState.selectedImageID = newValue.itemIdentifier
//                            print("----------------------")
//                            print("itemIdentifier = \(newValue.itemIdentifier)")
//                            print("----------------------")

                            scopeState.selectedImageData = data
                            dismissClosure()

                        }
                    }
                }
        #endif
    }
}

#if os(iOS)
/// Wraps UIActivityViewController for use in SwiftUI sheets.
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif













