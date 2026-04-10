import SwiftUI
import Combine
import simd

enum DragLocations: String {
    case inRotationCenter
    case inTrianglePoint1
    case inTrianglePoint2
    case inTrianglePoint3
    case inTriangleBody
    case outsideTriangle
}

typealias DragPointTuple = (point: CGPoint, dragLocation: DragLocations)

class ScopeState: ObservableObject {
    
    @Published var selectedImageData: Data? = nil
    
    let example = "example"
    let test2 = "test 2"
    let portrait = "portrait"
    let landscape = "landscape"

    @Published var textureName = "example"
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
    
    @Published var rotationCenter: SIMD2<Float> = [0.5, 0.5] {
        didSet {
            //print("rotationCenter changed")
        }
    }


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
        }
    }
    @Published var rotationSpeed: CGFloat = 10.0 // In degrees per second
    @Published var movementSpeed: CGFloat = 0 // In screen units per second.
    @Published var lastAnimationStepTime: CFTimeInterval = CACurrentMediaTime()
    @Published var texAspect: Float = 1
    @Published var texSize: CGSize = CGSize(width: 400, height: 400 )
    @Published var draggingState: DragLocations? = nil
    @Published var lastDragLocation: CGPoint? = nil
    @Published var previousRotation: Float? = nil
    
    @Published var imageViewSize: CGSize = CGSizeZero {
        willSet {
            //print("about to change imageViewSize")
        }
        didSet {
            //print("imageViewSize = \(imageViewSize)")
        }
    }
    @Published var texture: MTLTexture? {
        didSet {
            Task { @MainActor in
                guard let texture else { return }
                trianglePoints = calcTrianglePoints()
                let texWidth = CGFloat(texture.width)
                let texHeight = CGFloat(texture.height)
                texSize = CGSize(width: texWidth, height: texHeight)
                texAspect = Float(texWidth / texHeight)
            }
        }
    }

    private var trianglePoint1: CGPoint = CGPointZero
    private var trianglePoint2: CGPoint = CGPointZero
    private var trianglePoint3: CGPoint = CGPointZero
    private var rotationCenterPoint: CGPoint = CGPointZero
    
    typealias AdjustmentResult = (points: TrianglePoints, adjusted: Bool, xAdjustment: Float?, yAdjustment: Float?)
    
    func adjustTrianglePoints(trianglePoints: TrianglePoints) -> AdjustmentResult {
        let textureLimits: RangeLimits = (minX: 0, maxX: texAspect, minY: 0, maxY: 1)
        let triangleLimits = triangleLimits(trianglePoints: trianglePoints)
        var xAdjustment: Float? = nil
        var yAdjustment: Float? = nil
        //if out of range in x, calc x adjustment
        if triangleLimits.minX < textureLimits.minX {
            xAdjustment = textureLimits.minX - triangleLimits.minX
        } else if triangleLimits.maxX > textureLimits.maxX {
            xAdjustment = textureLimits.maxX - triangleLimits.maxX
        }
        if triangleLimits.minY < textureLimits.minY {
            yAdjustment = textureLimits.minY - triangleLimits.minY
        } else if triangleLimits.maxY > textureLimits.maxY {
            yAdjustment = textureLimits.maxY - triangleLimits.maxY
        }
        let adjusted = xAdjustment != nil || yAdjustment != nil
        if adjusted {
            let deltaX = xAdjustment ?? 0.0
            let deltaY = yAdjustment ?? 0.0
            let newTrianglePoints = TrianglePoints(
                point1: SIMD2<Float>(trianglePoints.point1.x + deltaX, trianglePoints.point1.y + deltaY),
                point2: SIMD2<Float>(trianglePoints.point2.x + deltaX, trianglePoints.point2.y + deltaY),
                point3: SIMD2<Float>(trianglePoints.point3.x + deltaX, trianglePoints.point3.y + deltaY))
            return (newTrianglePoints, true, xAdjustment, yAdjustment)
        }
        return (trianglePoints, false, xAdjustment, yAdjustment)
    }
    
    func calcTrianglePoints() -> TrianglePoints {
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
        let point3 = SIMD2<Float>(point1[0] + deltaX, point1[1] + deltaY)
        deltaY = Float(sin(centerAngle - stepArc)) * radius
        deltaX = Float(cos(centerAngle - stepArc)) * radius
        let point2 = SIMD2<Float>(point1[0] + deltaX, point1[1] + deltaY)

        return TrianglePoints(point1: point1, point2: point2, point3: point3)
    }

    func metalPointToView(_ metalPoint: SIMD2<Float>) -> CGPoint {
        return CGPoint(
            x: CGFloat(metalPoint.x.interpolated(from: 0...1, to: 0...Float(imageViewSize.width))),
            y: imageViewSize.height - CGFloat(metalPoint.y.interpolated(from: 0...1, to: 0...Float(imageViewSize.height))))
    }

    func viewPointToMetal(_ viewPoint: CGPoint ) -> SIMD2<Float> {
        return SIMD2<Float>(
            x: Float(viewPoint.x).interpolated(from:0...Float(imageViewSize.width), to: 0...1),
            y: Float(imageViewSize.height-viewPoint.y).interpolated(from:0...Float(imageViewSize.height), to: 0...1)
            )
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
        if pointInTriangle(
            tapPoint,
            p1: points[1].point,
            p2: points[2].point,
            p3: points[3].point) {
                return (tapPoint, .inTriangleBody)
            }
        return (tapPoint, .outsideTriangle)
    }
    /*
     + (BOOL) isRightHandTurnFromV1: (NSPoint) endpoint1
     endpoint2: (NSPoint) endpoint2
                                                             pointToTest: (NSPoint) pointToTest;
     {
         CGFloat z;
         z = endpoint1.x * (endpoint2.y - pointToTest.y) +
     endpoint2.x * (pointToTest.y - endpoint1.y) +
     pointToTest.x * (endpoint1.y - endpoint2.y);
         return signbit(z);
     }

     */
    func pointIsRighthandTurnFromEndpoints(_ pointToTest: CGPoint, endpoint1: CGPoint, endpoint2: CGPoint) -> Bool {
        let z = endpoint1.x * (endpoint2.y - pointToTest.y) +
        endpoint2.x * (pointToTest.y - endpoint1.y) +
        pointToTest.x * (endpoint1.y - endpoint2.y);

        return z < 0
    }
    
    func pointInTriangle(_ testPoint: CGPoint,
                         p1: CGPoint,
                         p2: CGPoint,
                         p3: CGPoint) -> Bool {
        let direction1 = pointIsRighthandTurnFromEndpoints(testPoint,
                                                           endpoint1: p1,
                                                           endpoint2: p2)
        let direction2 = pointIsRighthandTurnFromEndpoints(testPoint,
                                                           endpoint1: p2,
                                                           endpoint2: p3)
        let direction3 = pointIsRighthandTurnFromEndpoints(testPoint,
                                                           endpoint1: p3,
                                                           endpoint2: p1)
        return (direction1 == direction2 && direction2 == direction3)
    }
    
    func getDragLocation(_ startLocation: CGPoint) -> DragPointTuple? {
        
        trianglePoint1 = metalPointToView(trianglePoints.point1)
        trianglePoint2 = metalPointToView(trianglePoints.point2)
        trianglePoint3 = metalPointToView(trianglePoints.point3)
        rotationCenterPoint = metalPointToView(rotationCenter)
        let points: [DragPointTuple] = [
            (rotationCenterPoint, .inRotationCenter),
            (trianglePoint1, .inTrianglePoint1),
            (trianglePoint2, .inTrianglePoint2),
            (trianglePoint3, .inTrianglePoint3)
        ]
        if false {
            print("imageViewSize = \(imageViewSize)")
            print("rotationCenter = \(rotationCenter.myDescription)")
            print("You tapped on \(startLocation)")
            print("rotationCenterPoint = \(rotationCenterPoint)")
            print("trianglePoint1 = \(trianglePoint1)")
            print("trianglePoint2 = \(trianglePoint2)")
            print("trianglePoint3 = \(trianglePoint3)")
        }
        let aspect = imageViewSize.width / imageViewSize.height
        let adjusted = CGPoint(x: startLocation.x * aspect, y: startLocation.y)
        //print("Adjusted tap point = \(adjusted)")
        let result = matchPoint(adjusted, inPoints: points)
        return result
    }

    func changeAnimationState() {
        if animate {
            lastAnimationStepTime = CACurrentMediaTime()
        }
    }
    
    func rotateTriangleByAngle(_ angle: Float) {
        
        guard !angle.isNaN else { return }
        
        var rotationAngle: Float = angle
        if let previousRotation {
            rotationAngle = fmod(angle - previousRotation, Float.pi * 2)
        }
            
        let pivotPoint = centerPoint(trianglePoints: trianglePoints)
        trianglePoints = rotateTriangle(trianglePoints: trianglePoints, angle: rotationAngle, aroundCenter: pivotPoint)
        if trianglePoints.point1.x.isNaN {
            print("NAN!")
        }

        previousRotation = angle
    }
    
    func positionVector(point: simd_float2) -> simd_float3 {
        return simd_float3(x: point.x, y: point.y, z: 1)
    }
    
    func pointFromVector(_ vector: simd_float3) -> simd_float2 {
        return simd_float2(vector.x, vector.y)
    }
    
    func shiftPoint(_ point: inout simd_float2, by offset: simd_float2) {
        point += offset
    }

    func scaleTrianglePoints(by scale: Float, centeredAt center: simd_float2) -> TrianglePoints{
        //print("center = \(center.myDescription)")
        let scaleMatrix = makeScaleMatrix(xScale: scale, yScale: scale)

                let translation = makeTranslationMatrix(tx: -center.x, ty: -center.y)
                let reverseTranslation = makeTranslationMatrix(tx: center.x , ty: center.y )
        
//  -- This code does not work. The translationMatrix has no effect. Why?
        let transform = translation * scaleMatrix * reverseTranslation
        let point1 = ((positionVector(point: trianglePoints.point1)) * transform)
        let point2 = ((positionVector(point: trianglePoints.point2))  * transform)
        let point3 = ((positionVector(point: trianglePoints.point3))  * transform)
        return TrianglePoints(
            point1: pointFromVector(point1),
            point2: pointFromVector(point2),
            point3: pointFromVector(point3)
            )
    }
    
    func handleDragging(
        value: DragGesture.Value,
        flags: UInt
    ) {
        guard let lastDragLocation = lastDragLocation else { return }
        let aspect = imageViewSize.width / imageViewSize.height
        
        let deltaX = (value.location.x - lastDragLocation.x) * aspect
        let deltaY = value.location.y - lastDragLocation.y
        //print("You moved by (x: \(deltaX), y: \(deltaY)")

        switch draggingState {
        case .inTrianglePoint1, .inTrianglePoint2, .inTrianglePoint3:
            let triangleCGPoint = TriangleCGPoints(point1: trianglePoint1, point2: trianglePoint2, point3: trianglePoint3)
            let centerCGPoint = centerCGPoint(triangleCGPoints: triangleCGPoint)
            let startingDistance = distanceBetween(p1: centerCGPoint, p2: lastDragLocation)
            let currentDistance = distanceBetween(p1: centerCGPoint, p2: value.location)
            let sizeChange = Float(currentDistance/startingDistance)
            
            //let changeString = String(format: "%.02f", sizeChange)
            //let startingDistanceString = String(format: "%.02f", startingDistance)
            //let currentDistanceString = String(format: "%.02f", currentDistance)
            //print("startingDistance = \(startingDistanceString). currentDistance = \(currentDistanceString). change = \(changeString)")
            let triangleCenter = centerPoint(trianglePoints: trianglePoints)
            let changed = scaleTrianglePoints(by: sizeChange, centeredAt: triangleCenter)
            let adjustment = adjustTrianglePoints(trianglePoints: changed)
            trianglePoints = adjustment.points

            self.lastDragLocation = value.location

        case .inRotationCenter:
            let newCenterPoint = CGPoint(x: rotationCenterPoint.x + deltaX, y: rotationCenterPoint.y + deltaY)
            let newRotationCenter = viewPointToMetal(newCenterPoint)
            
            self.rotationCenter = newRotationCenter
        case .inTriangleBody:
            let newPoint1 = CGPoint(x: trianglePoint1.x + deltaX, y: trianglePoint1.y + deltaY)
            let newPoint1Metal = viewPointToMetal(newPoint1)
            let newPoint2 = CGPoint(x: trianglePoint2.x + deltaX, y: trianglePoint2.y + deltaY)
            let newPoint2Metal = viewPointToMetal(newPoint2)
            let newPoint3 = CGPoint(x: trianglePoint3.x + deltaX, y: trianglePoint3.y + deltaY)
            let newPoint3Metal = viewPointToMetal(newPoint3)

            let changed = TrianglePoints(point1: newPoint1Metal, point2: newPoint2Metal, point3: newPoint3Metal)
            let adjustment = adjustTrianglePoints(trianglePoints: changed)
            trianglePoints = adjustment.points

            #if os(macOS)
                if NSEvent.modifierFlags.rawValue & NSEvent.ModifierFlags.shift.rawValue != 0 {
                                     let newCenterPoint = CGPoint(x: rotationCenterPoint.x + deltaX, y: rotationCenterPoint.y + deltaY)
                                     let newRotationCenter = viewPointToMetal(newCenterPoint)
                         
                                     self.rotationCenter = newRotationCenter
                }
            #endif


        case .outsideTriangle:
            let triangleCGPoint = TriangleCGPoints(point1: trianglePoint1, point2: trianglePoint2, point3: trianglePoint3)
            var  roateAroundCenter: Bool = false
            #if os(macOS)
                roateAroundCenter = flags & NSEvent.ModifierFlags.option.rawValue != 0
            #endif
            let pivotPoint: CGPoint
            if roateAroundCenter {
                pivotPoint = centerCGPoint(triangleCGPoints: triangleCGPoint)
            } else {
                pivotPoint = rotationCenterPoint
            }
            let centerMetalPoint = viewPointToMetal(pivotPoint)
            

            let deltaX = value.location.x - pivotPoint.x
            let deltaY = value.location.y - pivotPoint.y
            let angle1 = Float(atan2(lastDragLocation.x - pivotPoint.x, lastDragLocation.y - pivotPoint.y))
            let angle2 = Float(atan2(deltaX, deltaY))
            let angleChange = angle2 - angle1
            let changed = rotateTriangle(trianglePoints: trianglePoints, angle: angleChange, aroundCenter: centerMetalPoint)
            self.lastDragLocation = value.location
            guard !changed.point1.x.isNaN else {
                print("NAN!")
                return
            }
            let adjustment = adjustTrianglePoints(trianglePoints: changed)
            trianglePoints = adjustment.points

        default:
            return
        }
    }

}

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
    
    let zoomDetents: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
    let radiusDetents: [Double] = [0.5, 0.6, 0.7, 0.8, 0.9, 1.0]

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
    
    @StateObject var scopeState = ScopeState()
//    @StateObject var scopeViewModel = ScopeViewModel(scopeState: scopeState)
        
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
                        //print("\nUser tapped in \(target.dragLocation.rawValue)\n")
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
                let draggingStateString = scopeState.draggingState?.rawValue ?? "nil"
                print("\ndragGesture ended. scopeState.draggingState = \(draggingStateString). texAspect = \(scopeState.texAspect).  TrianglePoints = \n\(scopeState.trianglePoints)")

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
                    Button(scopeState.animate ? "Stop" : "Animate") {
                        scopeState.animate.toggle()
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








