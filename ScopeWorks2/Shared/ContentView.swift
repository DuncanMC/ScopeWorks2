import SwiftUI
import Combine

class ScopeState: ObservableObject {
    @Published var selectedImageData: Data? = nil
    
    
    let example = "example"
    let test2 = "test 2"
    let portrait = "portrait"
    let landscape = "landscape"

    @Published var textureName = "landscape"
    var selectedImageSize: CGSize {
        guard let selectedImageData else { return .zero }
        #if os(iOS)
                guard  let selectedImage: UIImage = UIImage(data: selectedImageData) else {return CGSizeZero}
                return CGSize(width: selectedImage.size.width, height: selectedImage.size.height)
        #elseif os(macOS)
                guard  let selectedImage = NSImage(data: selectedImageData) else {return CGSizeZero}
                return CGSize(width: selectedImage.size.width, height: selectedImage.size.height)
        #endif
    }

    var selectedImageAspectRatio: Float {
        guard selectedImageData != nil,
                selectedImageSize.width > 0 else { return 0 }
        return Float(selectedImageSize.width / selectedImageSize.height)
    }
    @Published var zoom: Double = 2.0 // use a range of 1.0 to 5.0
    @Published var radiusScale: Float = 1.0
    @Published var trianglePoints = TrianglePoints(point1: zeroPoint, point2: zeroPoint, point3: zeroPoint)
    @Published var rotationCenter: SIMD2<Float> = [0.5, 0.5] //TODO

    @Published var selectedScopeType: Int = 0

    @Published var showOutlines: Bool = false
    @Published var useBlackBackground: Bool = false
    @Published var flipAlternates: Bool = true
    @Published var showSourceImage: Bool = true
    @Published var drawWithReflection: Bool = true
    @Published var animate: Bool = false
    @Published var polygonSides = 6
    @Published var rotationSpeed: CGFloat = 10.0 // In degrees per second
    @Published var movementSpeed: CGFloat = 0 // In screen units per second.
    @Published var lastAnimationStepTime: CFTimeInterval = CACurrentMediaTime()
    @Published var texture: MTLTexture? {
        didSet {
            Task { @MainActor in
                trianglePoints = calcTrianglePoints()
                rotationCenter = centerPoint(trianglePoints: trianglePoints)
            }
        }
    }

    func calcTrianglePoints()
    -> TrianglePoints {
        guard selectedImageData != nil else {
            return (TrianglePoints(point1: zeroPoint, point2: zeroPoint, point3: zeroPoint))
        }

        let point1 = SIMD2<Float>(0.4, 0.25)
        let point2 = SIMD2<Float>(0.6, 0.25)
        let base =  point2[0] - point1[0]
        let angle = .pi / 3.0
        let deltaY = Float(sin(angle)) * base
        let deltaX = Float(cos(angle)) * base
        let point3 = SIMD2<Float>(point1[0] + deltaX, point1[1] + deltaY)
        return TrianglePoints(point1: point1, point2: point2, point3: point3)
    }


}

class ScopeViewModel: ObservableObject {
    var scopeState: ScopeState
    init(scopeState: ScopeState) {
        self.scopeState = scopeState
//        let scopeTemplates = ScopeWorks2App.scopeTemplates
//        for aTemplate in scopeTemplates {
//            print(aTemplate)
//        }
    }
    
    func changeAnimationState() {
        if scopeState.animate {
            scopeState.lastAnimationStepTime = CACurrentMediaTime()
        }
    }
}

struct ContentView: View {
    
    let zoomDetents: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
    let radiusDetents: [Double] = [0.5, 0.6, 0.7, 0.8, 0.9, 1.0]

    var zoomString: String {
        String(format:"%.02f", scopeState.zoom)
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
    
    @StateObject var scopeState = ScopeState()
    @StateObject var scopeViewModel = ScopeViewModel(scopeState: ScopeState())
    
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
                        .aspectRatio(1.0, contentMode: .fit)
 //                        .border(.black)

                }
                ScopeViewRepresentable(scopeState: scopeState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
            }
            Spacer()
            ScrollView(.horizontal) {
                VStack(spacing: 10) {
                    HStack(alignment: .center, spacing: 20) {
                        Spacer()
    #if os(iOS)
                        PhotoPickerView(scopeState: scopeState)
    #endif
                        
                        ScopeTypePicker(title: "Kaledioscope Type:", options: ScopeWorks2App.scopeTemplateNamesAndIndexes, selection: $scopeState.selectedScopeType )
                            .frame(width: 360)

                            .onChange(of: scopeState.selectedScopeType) { oldValue, newValue in
//                                print("selectedScopeType = \(newValue)")
                            }
                        
                        
                        LabeledContent(content: {
                            TextField("",
                                      text: $polygonSidesString,
                                      onEditingChanged: { isEditing in
//                                print("In onEditingChanged isEditing = \(isEditing), $polygonSidesString = \(polygonSidesString)")
                            },
                                      onCommit: {
//                                print("In onCommit, $polygonSidesString = \(polygonSidesString)")
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
                        Toggle(isOn: $scopeState.useBlackBackground) {
                            Text("Use black background")
                                .frame(maxWidth: .infinity, alignment: toggleAlignment)
                        }
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
                    Toggle(isOn: $scopeState.animate) {
                        Text("Animate")
                            .frame(maxWidth: .infinity, alignment: toggleAlignment)
                    }
                    .onChange(of: scopeState.animate) { oldValue, newValue in
                        scopeViewModel.changeAnimationState()
                    }
                    Button("Reverse animation") {
                        scopeState.rotationSpeed *= -1
                        scopeState.movementSpeed *= -1
                    }
                    Spacer()
                }
            }
            }
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
        }
    }
}

#if os(iOS)
import PhotosUI

struct PhotoPickerView: View {
    
    @State private var selectedItem: PhotosPickerItem?
    @StateObject var scopeState: ScopeState
    

    var body: some View {
        PhotosPicker("Select Texture", selection: $selectedItem, matching: .images)
            .onChange(of: selectedItem) { oldValue, newValue in
                Task {
                    if let newValue,
                       let data = try? await newValue.loadTransferable(type: Data.self) {
                        scopeState.selectedImageData = data
                    }
                }
            }
    }
}
#endif






