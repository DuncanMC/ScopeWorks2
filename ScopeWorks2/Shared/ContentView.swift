import SwiftUI
import Combine
import simd
import PhotosUI




//class ScopeViewModel: ObservableObject {
//    var scopeState: ScopeState
//    
//    init(scopeState: ScopeState) {
//        self.scopeState = scopeState
//    }
//    
//    
//}

struct ContentView: View {
        
    @Binding var scopeState: ScopeState

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
                if scopeState.showSourceImage {
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
                            HStack {
                                Spacer()
                                    .frame(maxWidth: .infinity)
                                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 20))
                                Toggle(isOn: $scopeState.showControls) {
                                    Text("Show controls")

                                        .lineLimit(1)
                                        .frame(minWidth: 120, alignment: .trailing)
                                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 5))
                                }
                                .padding(EdgeInsets(top: 3, leading: 5, bottom: 3, trailing: 5))
                                .background(Color.white.opacity(0.75))
                                .onChange(of: scopeState.showControls) { oldValue, newValue in
                                    print("in onChange, newValue = \(newValue)")
                                    let urlPath = scopeState.imageURL?.path ?? "nil"
                                    print("uuid = \(scopeState.uuid). imageURL = \(urlPath)")
                                }
                                
                                .keyboardShortcut("t", modifiers: [.command])
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            }
                        }
                    }
                }
            }
            if scopeState.showControls {
                Spacer()
                ScrollView(.horizontal) {
                    VStack(spacing: 10) {
                        HStack(alignment: .center, spacing: 20) {
                            Spacer()
                            PhotoPickerView(scopeState: scopeState)
                            
                            ScopeTypePicker(title: "Kaleidoscope Type:", options: ScopeWorks2App.scopeTemplateNamesAndIndexes, selection: $scopeState.selectedScopeType )
                                .frame(width: 360)
                            
                                .onChange(of: scopeState.selectedScopeType) { oldValue, newValue in
                                    //print("selectedScopeType = \(newValue)")
                                }
                            
                            
                            LabeledContent(content: {
                                TextField("",
                                          text: $polygonSidesString,
                                          onEditingChanged: { isEditing in
                                    //print("In onEditingChanged isEditing = \(isEditing), $polygonSidesString = \(polygonSidesString)")
                                },
                                          onCommit: {
                                    //print("In onCommit, $polygonSidesString = \(polygonSidesString)")
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
                                .onChange(of: isFocused) {
                                    if isFocused {
#if os(iOS)
                                        Task { @MainActor in
                                            UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
                                        }
#elseif os(macOS)
                                        Task { @MainActor in
                                            NSApplication.shared.tryToPerform(#selector(NSResponder.selectAll(_:)), with: nil)
                                        }
#endif
                                        selection = .init(range: site.startIndex..<site.endIndex)
                                    }
                                }
                                .onAppear() {
                                    polygonSidesString = "\(scopeState.polygonSides)"
                                }
                            },
                                           label: {
                                Text("Polygon sides")
                                
                            })
                            .padding()
                            
                            Toggle(isOn: $scopeState.showOutlines) {
                                Text("Show outlines")
                                    .frame(maxWidth: .infinity, alignment: toggleAlignment)
                            }
                            Toggle(isOn: $scopeState.showSourceImage) {
                                Text("Show source image")
                                    .frame(maxWidth: .infinity, alignment: toggleAlignment)
                            }
                            .keyboardShortcut("i", modifiers: [.command])
                            
                            ColorPicker("Background color", selection: $scopeState.backgroundColor)
                            //                        Toggle(isOn: $scopeState.useBlackBackground) {
                            //                            Text("Use black background")
                            //                                .frame(maxWidth: .infinity, alignment: toggleAlignment)
                            //                        }
                            Spacer()
                            
                            // Visual detents and snapping for iOS 18+/macOS 26+
                            VStack {
                                Text("Zoom \(zoomString)")
                                Slider(value: $scopeState.zoom, in: 2.0 ... 5.0)
                            }
                            //                        , neutralValue: { editing in
                            //                                if !editing {
                            //                                    let threshold = 0.1
                            //                                    if let nearest = zoomDetents.min(by: { abs($0 - scopeState.zoom) < abs($1 - scopeState.zoom) }),
                            //                                       abs(nearest - scopeState.zoom) < threshold {
                            //                                        scopeState.zoom = nearest
                            //                                    }
                            //                                }
                            //                            }) {
                            //                                Text("Zoom")
                            //                            } label: {
                            //                                SliderTickContentForEach(zoomDetents, id: \.self) { val in
                            //                                    SliderTick(val) {
                            //                                        Text(String(format: "%.1f", val))
                            //                                    }
                            //                                }
                            //                            }
                            //                        }
                            Spacer()
                            VStack {
                                Text("Radius \(radiusString)")
                                Slider(value: $scopeState.radiusScale, in: 0.5...1.0)
                                //                            , onEditingChanged: { editing in
                                //                                if !editing {
                                //                                    let threshold = 0.05
                                //                                    if let nearest = radiusDetents.min(by: { abs($0 - scopeState.radiusScale) < abs($1 - scopeState.radiusScale) }),
                                //                                        abs(nearest - scopeState.radiusScale) < threshold {
                                //                                        scopeState.radiusScale = nearest
                                //                                    }
                                //                                }
                                //                            }) {
                                //                                Text("Radius")
                                //                            } ticks: {
                                //                                SliderTickContentForEach(radiusDetents, id: \.self) { val in
                                //                                    SliderTick(val) {
                                //                                        Text(String(format: "%.2f", val))
                                //                                    }
                                //                                }
                                //                            }
                            }
                            //radiusScale
                        }
                        HStack(alignment: .center,spacing: 20) {
                            Spacer()
                            
                            Toggle(isOn: $scopeState.flipAlternates) {
                                Text("Flip alternates")
                                    .frame(maxWidth: .infinity, alignment: toggleAlignment)
                            }
                            Toggle(isOn: $scopeState.drawWithReflection) {
                                Text("Draw with reflection")
                                    .frame(maxWidth: .infinity, alignment: toggleAlignment)
                            }
                            VStack {
                                Text("Rotation speed \(rotationString)")
                                Slider(value: $scopeState.rotationSpeed, in: 0 ... 15.0)
                            }
                            
                            Button(scopeState.animate ? "Stop" : "Animate") {
                                scopeState.animate.toggle()
//                                scopeState.animateButtonTitle = scopeState.animate ? "Stop" : "Animate"
                            }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.defaultAction)
                            //                    Toggle(isOn: $scopeState.animate) {
                            //                        Text("Animate")
                            //                            .frame(maxWidth: .infinity, alignment: toggleAlignment)
                            //                    }
                            .onChange(of: scopeState.animate) { oldValue, newValue in
                                scopeState.changeAnimationState()
                            }
                            Button("Reverse animation") {
                                scopeState.rotationSpeed *= -1
                                scopeState.movementSpeed *= -1
                            }
                            .keyboardShortcut("r", modifiers: [.command])
                            
                            Button("Save") {
                                NotificationCenter.default.post(name: requestSaveDocument, object: nil)
                            }
                            .keyboardShortcut("s", modifiers: [.command])
                            
                            Spacer()
                        }
                    }
                }
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                
            }
            //xxx
        }
    }
}



struct PhotoPickerView: View {
    
    @State private var selectedItem: PhotosPickerItem?
    @ObservedObject var scopeState: ScopeState
    
    
    var body: some View {
        #if os(macOS)
            Button("Choose image") {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseFiles = true
                panel.canChooseDirectories = false
                if panel.runModal() == .OK,
                let url = panel.url {
                    scopeState.imageURL = url
                    scopeState.bookmarkData = createSecurityScopedBookmark(for: url)
                    print("bookmarkData = \(String(describing: scopeState.bookmarkData))")
                    if let typeID = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier {
                        print("typeID = \(typeID)")
                        scopeState.isHEIC =  typeID == UTType.heic.identifier
                    }
                }
//                scopeState.showOpenDialog = true
            }
        
        #else
        PhotosPicker("Choose image", selection: $selectedItem, matching: .images, photoLibrary: .shared())
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
                        }
                    }
                }
        #endif
    }
}















