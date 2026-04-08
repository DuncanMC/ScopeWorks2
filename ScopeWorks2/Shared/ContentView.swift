import SwiftUI
import Combine
import simd

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
    @Published var trianglePoints = TrianglePoints(
        point1: SIMD2<Float>(0.4, 0.25),
        point2: SIMD2<Float>(0.6, 0.25),
        point3: SIMD2<Float>(0.5, 0.42320508))
    
    @Published var rotationCenter: SIMD2<Float> = [0.5, 0.5] //TODO

    @Published var selectedScopeType: Int = 0

    @Published var showOutlines: Bool = false
    @Published var useBlackBackground: Bool = false
    @Published var flipAlternates: Bool = true
    @Published var splitTriangle: Bool = false
    @Published var showSourceImage: Bool = true
    @Published var drawWithReflection: Bool = true
    @Published var animate: Bool = false
    @Published var polygonSides = 6 {
        didSet {
            trianglePoints = calcTrianglePoints()
            rotationCenter = centerPoint(trianglePoints: trianglePoints) // TODO: Remove this 
            
        }
    }
    @Published var rotationSpeed: CGFloat = 10.0 // In degrees per second
    @Published var movementSpeed: CGFloat = 0 // In screen units per second.
    @Published var lastAnimationStepTime: CFTimeInterval = CACurrentMediaTime()
    @Published var texAspect: Float = 1
    @Published var texSize: CGSize = CGSize(width: 400, height: 400 )
    @Published var imageViewSize: CGSize = CGSizeZero {
        didSet{
            print("imageViewSize = \(imageViewSize)")
        }
    }
    @Published var texture: MTLTexture? {
        didSet {
            Task { @MainActor in
                guard let texture else { return }
                trianglePoints = calcTrianglePoints()
//                rotationCenter = centerPoint(trianglePoints: trianglePoints)
                let texWidth = CGFloat(texture.width)
                let texHeight = CGFloat(texture.height)
                texSize = CGSize(width: texWidth, height: texHeight)
                texAspect = Float(texWidth / texHeight)
//                print("After loading texture, texWidth = \(texWidth). texHeight =  \(texWidth). texAspect = \(texAspect)")
            }
        }
    }

    func calcTrianglePoints()
    -> TrianglePoints {
        guard selectedImageData != nil else {
            return TrianglePoints(
                point1: SIMD2<Float>(0.4, 0.25),
                point2: SIMD2<Float>(0.6, 0.25),
                point3: SIMD2<Float>(0.5, 0.42320508))
        }

        
        let midpoint = midpoint(p1: trianglePoints.point2, p2: trianglePoints.point3)
        let point1 = trianglePoints.point1
        let centerAngle = atan2(Double(midpoint.y - point1.y), Double(midpoint.x - point1.x) )
        
        
        
        let stepArc = Double.pi / Double(polygonSides)
        let radius = distanceBetween(p1: point1, p2: trianglePoints.point2)
        var deltaY = Float(sin(centerAngle + stepArc)) * radius
        var deltaX = Float(cos(centerAngle + stepArc)) * radius
        let point2 = SIMD2<Float>(point1[0] + deltaX, point1[1] + deltaY)
        deltaY = Float(sin(centerAngle - stepArc)) * radius
        deltaX = Float(cos(centerAngle - stepArc)) * radius
        let point3 = SIMD2<Float>(point1[0] + deltaX, point1[1] + deltaY)

        return TrianglePoints(point1: point1, point2: point2, point3: point3)
    }


}

class ScopeViewModel: ObservableObject {
    var scopeState: ScopeState
    init(scopeState: ScopeState) {
        self.scopeState = scopeState
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
    
    @State private var isDragging = false
    
    @StateObject var scopeState = ScopeState()
    @StateObject var scopeViewModel = ScopeViewModel(scopeState: ScopeState())
    
    enum DragLocations: String {
        case inRotationCenter
        case inTrianglePoint1
        case inTrianglePoint2
        case inTrianglePoint3
        case inTriangleBody
    }

    typealias DragPointTuple = (point: CGPoint, dragLocation: DragLocations)

    func metalPointToView(_ metalPoint: SIMD2<Float>) -> CGPoint {
        return CGPoint(
            x: CGFloat(metalPoint.x.interpolated(from: 0...1, to: 0...Float(scopeState.imageViewSize.width))),
            y: scopeState.imageViewSize.height - CGFloat(metalPoint.y.interpolated(from: 0...1, to: 0...Float(scopeState.imageViewSize.height))))
    }
    func matchPoint(_  tapPoint: CGPoint, inPoints points: [DragPointTuple]) -> DragPointTuple? {
        let slop: CGFloat = 20
        for (aPoint, location) in points {
            if tapPoint.x > aPoint.x - slop && tapPoint.x < aPoint.x + slop &&
                tapPoint.y > aPoint.y - slop && tapPoint.y < aPoint.y + slop
            {
                    return (aPoint, location)
            }
        }
        return nil
    }
    
    func getDragLocation(_ startLocation: CGPoint) -> DragPointTuple? {
        
        let trianglePoint1 = metalPointToView(scopeState.trianglePoints.point1)
        let trianglePoint2 = metalPointToView(scopeState.trianglePoints.point2)
        let trianglePoint3 = metalPointToView(scopeState.trianglePoints.point3)
        let rotationCenterPoint = metalPointToView(scopeState.rotationCenter)
        let points: [DragPointTuple] = [
            (rotationCenterPoint, .inRotationCenter),
            (trianglePoint1, .inTrianglePoint1),
            (trianglePoint2, .inTrianglePoint2),
            (trianglePoint3, .inTrianglePoint3)
        ]
        return matchPoint(startLocation, inPoints: points)
//        print("imageViewSize = \(scopeState.imageViewSize)")
//        print("rotationCenter = \(scopeState.rotationCenter.myDescription)")
//        print("You tapped on \(startLocation)")
//        print("rotationCenterPoint = \(rotationCenterPoint)")
//        print("trianglePoint1 = \(trianglePoint1)")
//        print("trianglePoint2 = \(trianglePoint2)")
//        print("trianglePoint3 = \(trianglePoint3)")
//        return nil
    }
    
    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging {
                    print("Begin dragging in view.")
                    if let target = getDragLocation( value.startLocation) {
                        print("User tapped in \(target.dragLocation.rawValue)")
                        if target.dragLocation == .inRotationCenter {
                            
                        }
                    } else {
                        print("User did not tap in a known location")
                    }
                    /*
                     check for tap/drag in:
                        center location
                        triangle corner
                        triangle body
                        anywhere not in one of those places.
                     */
                    self.isDragging = true
                }
            }
            .onEnded { value in
                self.isDragging = false
                print("ended drag event")
            }
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
                    GeometryReader { geometry in
                        Task { @MainActor in
                            if scopeState.imageViewSize != geometry.size {
                                scopeState.imageViewSize = geometry.size
                            }
                        }
                        return SourceImageViewRepresentable(scopeState: scopeState)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.white)
                            .aspectRatio(scopeState.texSize, contentMode: .fit)
                            .border(.black)
                            .gesture(dragGesture)
                    }


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







