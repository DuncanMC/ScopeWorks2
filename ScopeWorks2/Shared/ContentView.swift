import SwiftUI
import Combine
import simd
import PhotosUI




enum ActiveModal: Identifiable {
    case imageSource
    case settings
//    case detail(itemId: String)
    
    var id: String {
        switch self {
        case .imageSource: "imageSource"
        case .settings: "settings"
//        case .detail(let id): "detail-\(id)"
        }
    }
}

struct ContentView: View {
    
    @State private var presentedModal: ActiveModal?

    var imageSourceLeading: CGFloat {
        #if os(macOS)
            return 7
        #else
            return 10
        #endif
    }

    var polygonSidesLeading: CGFloat {
        #if os(macOS)
            return 0
        #else
            return 6
        #endif
    }
    var kaleidoscopeTypeLeading: CGFloat {
    #if os(macOS)
        return 12
    #else
        return 10
        
#endif
    }
    
    var reverseAnimationLeading: CGFloat {
        #if os(macOS)
            return 75
        #else
            return 110
        #endif
    }

    var backgroundColorLeading: CGFloat {
        #if os(macOS)
            return 0
        #else
            return 12
        #endif
    }

    let sliderWidth = 350.0
    @ObservedObject var scopeState: ScopeState
    @StateObject private var externalDisplayManager: ExternalDisplayManager
    @Environment(\.undoManager) var undoManager

    init(scopeState: ScopeState) {
        self.scopeState = scopeState
        if let existing = scopeState.externalDisplayManager {
            _externalDisplayManager = StateObject(wrappedValue: existing)
        } else {
            let manager = ExternalDisplayManager(scopeState: scopeState)
            scopeState.externalDisplayManager = manager
            _externalDisplayManager = StateObject(wrappedValue: manager)
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
    
    @FocusState private var isFocused
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
    var body: some View {
        VStack {
            HStack {
                if scopeState.showSourceImage && !isFullScreen {
                    SourceImageViewRepresentable(scopeState: scopeState)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white)
                        .aspectRatio(scopeState.texSize, contentMode: .fit)
                        .border(.blue, width: 2)
                        .gesture(ExclusiveGesture(dragGesture, rotateGesture))
                    //                        .gesture(rotateGesture)
                }
                ZStack {
                    ScopeViewRepresentable(scopeState: scopeState)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white)
                    //                        Button(scopeState.showControls ? "Hide controls" : "Show controls") {
                    //                            print("Toggling scopeState.showControls. ScopeState uuid = \(scopeState.uuid)")
                    //                            scopeState.showControls.toggle()
                    //                        }
                    //                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    //                    } else {
                    VStack {
                        Spacer()
                            .frame(maxHeight: .infinity)
                        HStack(alignment: .center) {
                            Spacer()
                                .frame(maxWidth: .infinity)
//                            HStack {
//                                Spacer()
//                                    .frame(maxWidth: .infinity)
//                                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 20))
//                                Toggle(isOn: $scopeState.showControls) {
//                                    Text("Show controls")
//                                    
//                                        .lineLimit(1)
//                                        .frame(minWidth: 120, alignment: .trailing)
//                                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 5))
//                                }
//                                .padding(EdgeInsets(top: 3, leading: 5, bottom: 3, trailing: 5))
//                                .background(Color.white.opacity(0.75))
//                                .onChange(of: scopeState.showControls) { oldValue, newValue in
//                                    print("in onChange, newValue = \(newValue)")
//                                    let urlPath = scopeState.imageURL?.path ?? "nil"
//                                    print("uuid = \(scopeState.uuid). imageURL = \(urlPath)")
//                                }
//                                
////                                .keyboardShortcut("t", modifiers: [.command])
////                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
//                            }
                        }
                    }
                }
            }
            // xxx
            if scopeState.showControls && !isFullScreen {
                Spacer()
                ScrollView(.horizontal) {
                    HStack(spacing: 30) {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                //Image source button
                                Button("Image source") {
                                    presentedModal = .imageSource
                                }

                                Button("Reverse animation (⌘R)") {
                                    scopeState.rotationSpeed *= -1
                                    scopeState.movementSpeed *= -1
                                }
                                .padding(.leading, reverseAnimationLeading)
                                .keyboardShortcut("r", modifiers: [.command])


                            }
                            .padding(.leading, 0)
//                            .border(.blue, width: 1)

                            // External display picker
                            if !externalDisplayManager.availableDisplays.isEmpty {
                                HStack {
                                    Picker("Display:", selection: $externalDisplayManager.selectedDisplayID) {
                                        Text("None").tag(String?.none)
                                        ForEach(externalDisplayManager.availableDisplays) { display in
                                            Text(display.name).tag(Optional(display.id))
                                        }
                                    }
                                    .frame(minWidth: 200)
                                }
                            }

                            //Kaleidoscope type picker
                            ScopeTypePicker(title: "Kaleidoscope Type:", options: ScopeWorks2App.scopeTemplateNamesAndIndexes, selection: $scopeState.selectedScopeType )
                                .frame(width: 460)
                            
                                .onChange(of: scopeState.selectedScopeType) { oldValue, newValue in
                                    //print("selectedScopeType = \(newValue)")
                                }
                                .padding(.leading, kaleidoscopeTypeLeading)
                            
                            HStack {
                                //Polygon sides
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
                                        isFocused = false
                                    }
                                              
                                    )
                                    .textFieldStyle(.roundedBorder)
                                    .frame(minWidth: 30, maxWidth: 50)
                                    .focused($isFocused)
                                    .onAppear() {
#if os(macOS)
                                        Task { @MainActor in
                                            let _ = NSApp.keyWindow?.makeFirstResponder(nil)
                                        }
#endif
                                    }
                                    
                                    .onChange(of: isFocused) {
                                        if isFocused {
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
                                        .frame(minWidth: 130)

                                })
                                .padding(.leading, polygonSidesLeading)
                                //.border(.black, width: 1)
                                
                                //background color well
                                ColorPicker("Background color", selection: $scopeState.backgroundColor)
                                    .frame(minWidth: 200)
//                                .border(.black, width: 1)
                                .padding(.leading, backgroundColorLeading)

                            }

                        }

                        .padding(.leading, 10)
                        VStack(alignment: .leading, spacing: 20) { //Sliders
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

                                Slider(value: $scopeState.zoom, in: 2.0 ... 5.0)
                                    .frame(width: sliderWidth )
                                    .frame(minWidth: 150 )

                            }
                            // Radius
                            HStack {
                                Text("Radius: \(radiusString)")
                                    .frame(minWidth: 200, alignment: .leading)
//                                    .border(.black, width: 1)
                                Slider(value: $scopeState.radiusScale, in: 0.5...1.0)
                                    .frame(width: sliderWidth )
                                    .frame(minWidth: 150 )

                            }
                        }
                    }
                }
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                
            }
        }
        .sheet(item: $presentedModal) { modalType in
            switch modalType {
            case .settings:
                SettingsView()
            case .imageSource:
                ImageSouceView(scopeState: scopeState,
                               dismissClosure: {
                    presentedModal = nil
                })
            }
        }

#if os(iOS)
// MARK: hidden iOS menubar for keyboard shortcuts.
        .background {
            VStack {
                Toggle("Show controls", isOn: $scopeState.showControls)
                    .keyboardShortcut("c", modifiers: .option)
                Toggle("Show source image", isOn: $scopeState.showSourceImage)
                .keyboardShortcut("i", modifiers: .option)
                Toggle("Show outlines", isOn: $scopeState.showOutlines)
                .keyboardShortcut("o", modifiers: .option)
                Toggle("Flip alternates (⌥f)", isOn: $scopeState.flipAlternates)
                    .keyboardShortcut("f", modifiers: .option)
                Toggle("Draw with reflection (⌥r)", isOn: $scopeState.drawWithReflection)
                    .keyboardShortcut("r", modifiers: .option)
                Toggle("ANimate (↩)", isOn: $scopeState.animate)
                    .keyboardShortcut(.defaultAction)

                /*
                Toggle("xxx (⌥xxx)", isOn: $scopeState.xxx)
                 */


            }
            .frame(width: 0, height: 0)
            .opacity(0)

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
            if !scopeState.animate && scopeState.imageSourceMode == .staticImage {
                undoManager?.registerUndo(withTarget: scopeState) { _ in }
            }
        }
        .onChange(of: scopeState.animate) { _, newValue in
            if !newValue {
                undoManager?.registerUndo(withTarget: scopeState) { _ in }
            }
        }
#if os(iOS)
        .toolbar {
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
                    Toggle("Animate (↩)", isOn: $scopeState.animate)
                    Toggle("Show controls (⌥C)", isOn: $scopeState.showControls)
                    Toggle("Show source image (⌥I)", isOn: $scopeState.showSourceImage)
                    Toggle("Show outlines (⌥O)", isOn: $scopeState.showOutlines)
                    Toggle("Flip alternates (⌥f)", isOn: $scopeState.flipAlternates)
                    Toggle("Draw with reflection (⌥r)", isOn: $scopeState.drawWithReflection)
                    /*
                    Toggle("xxx (⌥xxx)", isOn: $scopeState.xxx)
                     */
                }
            }
        }
#endif

    }

}

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
                            print("----------------------")
                            print("itemIdentifier = \(newValue.itemIdentifier)")
                            print("----------------------")

                            scopeState.selectedImageData = data
                            dismissClosure()

                        }
                    }
                }
        #endif
    }
}
















