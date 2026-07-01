//
//  ScopeState.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 4/28/26.
//

import SwiftUI
import Combine
import simd
import PhotosUI

enum DragLocations: String {
    case inRotationCenter
    case inTrianglePoint1
    case inTrianglePoint2
    case inTrianglePoint3
    case inTriangleBody
    case outsideTriangle
}

typealias DragPointTuple = (point: CGPoint, dragLocation: DragLocations)

// MARK: - Persisted document properties:
// bookmarkData, imageURL, zoom, radiusScale, backgroundColor, trianglePoints,
// rotationCenter, showOutlines, flipAlternates, splitTriangle,
// drawWithReflection, animate, polygonSides,
// rotationSpeed, movementSpeed, selectedScopeType
class ScopeState: ObservableObject, Codable {
    


    var useButton: Bool = true
    
    // MARK: - Codable Keys
    enum CodingKeys: String, CodingKey {
        case imageID
        case imageURL
        case bookmarkData
        case zoom
        case radiusScale
        case backgroundColor
        case trianglePoints
        case rotationCenter
        case showOutlines
        case flipAlternates
        case splitTriangle
        case drawWithReflection
        case animate
        case polygonSides
        case rotationSpeed
        case movementSpeed
        case selectedScopeType
    }
    
    // MARK: - Codable support for Color
    struct CodableColor: Codable {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
        
        init(color: Color) {
            #if os(iOS)
            let uiColor = UIColor(color)
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            self.red = r
            self.green = g
            self.blue = b
            self.alpha = a
            #elseif os(macOS)
            let nsColor = NSColor(color)
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            nsColor.usingColorSpace(.deviceRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
            self.red = r
            self.green = g
            self.blue = b
            self.alpha = a
            #else
            self.red = 1
            self.green = 1
            self.blue = 1
            self.alpha = 1
            #endif
        }
        
        func toColor() -> Color {
            Color(.sRGB, red: Double(red), green: Double(green), blue: Double(blue), opacity: Double(alpha))
        }
    }
    
    // MARK: - Codable support for SIMD2<Float>
    struct CodableSIMD2: Codable {
        var x: Float
        var y: Float
        
        init(_ vector: SIMD2<Float>) {
            self.x = vector.x
            self.y = vector.y
        }
        
        func toSIMD2() -> SIMD2<Float> {
            SIMD2<Float>(x, y)
        }
    }
    
    struct TrianglePointsCodable: Codable {
        var point1: CodableSIMD2
        var point2: CodableSIMD2
        var point3: CodableSIMD2
        
        init(_ t: TrianglePoints) {
            self.point1 = CodableSIMD2(t.point1)
            self.point2 = CodableSIMD2(t.point2)
            self.point3 = CodableSIMD2(t.point3)
        }
        
        func toTrianglePoints() -> TrianglePoints {
            TrianglePoints(
                point1: point1.toSIMD2(),
                point2: point2.toSIMD2(),
                point3: point3.toSIMD2()
            )
        }
    }
    
    func doInitSetup() {


    }
    // MARK: - Initializer for decoding
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        #if os(macOS)
        self.bookmarkData = try container.decodeIfPresent(Data.self, forKey: .bookmarkData)
        if let data = self.bookmarkData {
            //                var fileURL: URL? = nil
            //                let documentController: NSDocumentController = .shared
            //                if let document = documentController.currentDocument {
            //                    fileURL = document.fileURL
            //                }
            //
            var bookmarkDataIsStale: Bool = false
            do {
                let imageURL = try URL(resolvingBookmarkData: data,
                                       options: .withSecurityScope,
                                       //                                           relativeTo: fileURL,
                                       bookmarkDataIsStale: &bookmarkDataIsStale)
                imageURL.startAccessingSecurityScopedResource()
                if bookmarkDataIsStale {
                    // TODO: Add code to handle bookmarkDataIsStale ==  true
                }
                self.imageURL = imageURL
            
            } catch {
                print("Error loading bookmark: \(error)")
            }
        }
        if self.imageURL == nil {
            self.imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
        }
        #else
        if let imageID = try? container.decodeIfPresent(String.self, forKey: .imageID) {
            print("in ScopeState.init(from:), found imageID: \(imageID)")
            self.selectedImageID = imageID
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [imageID], options: nil)
            if let asset = assets.firstObject {
                let imageManager = PHImageManager.default()
                imageManager.requestImageDataAndOrientation(for: asset, options: nil) { data, uti, orientation, info in
                    if let data {
                        self.selectedImageData = data
                    }
                }
            } else {
                self.imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
            }
                                                    
        } else {
            print("in ScopeState.init(from:), imageID = nil")

        }

        #endif

        self.polygonSides = try container.decode(Int.self, forKey: .polygonSides)

        self.zoom = try container.decode(Double.self, forKey: .zoom)
        self.radiusScale = try container.decode(Float.self, forKey: .radiusScale)
        let colorCodable = try container.decode(CodableColor.self, forKey: .backgroundColor)
        self.backgroundColor = colorCodable.toColor()
        
        let triangleCodable = try container.decode(TrianglePointsCodable.self, forKey: .trianglePoints)
        self.trianglePoints = triangleCodable.toTrianglePoints()
        
        let rotationCenterCodable = try container.decode(CodableSIMD2.self, forKey: .rotationCenter)
        self.rotationCenter = rotationCenterCodable.toSIMD2()
        
        self.showOutlines = try container.decode(Bool.self, forKey: .showOutlines)
        self.flipAlternates = try container.decode(Bool.self, forKey: .flipAlternates)
        self.splitTriangle = try container.decode(Bool.self, forKey: .splitTriangle)
        self.drawWithReflection = try container.decode(Bool.self, forKey: .drawWithReflection)
        self.animate = try container.decode(Bool.self, forKey: .animate)
//        self.showControls = try container.decode(Bool.self, forKey: .showControls)
        self.rotationSpeed = try container.decode(CGFloat.self, forKey: .rotationSpeed)
        self.movementSpeed = try container.decode(CGFloat.self, forKey: .movementSpeed)
        self.selectedScopeType = try container.decode(Int.self, forKey: .selectedScopeType)
        
        // Set default values for properties not persisted
        self.photoManager = PhotoLibraryManager()
        doInitSetup()

        print("In ScopeState init.from. uuid = \(uuid)")
    }
    
    // MARK: - Encode
    func encode(to encoder: Encoder) throws {
        print("----------------------")
        //print("In ScopeState.encode. selectedImageID = \(selectedImageID)")
        //print("trianglePoints = \(trianglePoints)")
        //print("----------------------")
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(bookmarkData, forKey: .bookmarkData)
        try container.encode(selectedImageID, forKey: .imageID)
        try container.encode(imageURL, forKey: .imageURL)
        try container.encode(zoom, forKey: .zoom)
        try container.encode(radiusScale, forKey: .radiusScale)
        try container.encode(CodableColor(color: backgroundColor), forKey: .backgroundColor)
        try container.encode(TrianglePointsCodable(trianglePoints), forKey: .trianglePoints)
        try container.encode(CodableSIMD2(rotationCenter), forKey: .rotationCenter)
        try container.encode(showOutlines, forKey: .showOutlines)
        try container.encode(flipAlternates, forKey: .flipAlternates)
        try container.encode(splitTriangle, forKey: .splitTriangle)
        try container.encode(drawWithReflection, forKey: .drawWithReflection)
        try container.encode(animate, forKey: .animate)
        try container.encode(polygonSides, forKey: .polygonSides)
        try container.encode(rotationSpeed, forKey: .rotationSpeed)
        try container.encode(movementSpeed, forKey: .movementSpeed)
        try container.encode(selectedScopeType, forKey: .selectedScopeType)
    }
    
    // MARK: - Convenience initializer for creating from document values
    init(
        imageURL: URL? = nil,
        zoom: Double = 2.0,
        radiusScale: Float = 1.0,
        backgroundColor: Color = Color.white,
        trianglePoints: TrianglePoints = TrianglePoints(
            point1: SIMD2<Float>(0.4, 0.25),
            point2: SIMD2<Float>(0.6, 0.25),
            point3: SIMD2<Float>(0.5, 0.42320508)
        ),
        rotationCenter: SIMD2<Float> = SIMD2<Float>(0.5, 0.5),
        showOutlines: Bool = false,
        flipAlternates: Bool = true,
        splitTriangle: Bool = false,
        drawWithReflection: Bool = true,
        animate: Bool = false,
        showControls: Bool = true,
        polygonSides: Int = 6,
        rotationSpeed: CGFloat = 10.0,
        movementSpeed: CGFloat = 0,
        selectedScopeType: Int = 0
    ) {
        self.imageURL = imageURL
        self.zoom = zoom
        self.radiusScale = radiusScale
        self.backgroundColor = backgroundColor
        self.trianglePoints = trianglePoints
        self.rotationCenter = rotationCenter
        self.showOutlines = showOutlines
        self.flipAlternates = flipAlternates
        self.splitTriangle = splitTriangle
        self.drawWithReflection = drawWithReflection
        self.animate = animate
        self.showControls = showControls
        self.polygonSides = polygonSides
        self.rotationSpeed = rotationSpeed
        self.movementSpeed = movementSpeed
        self.selectedScopeType = selectedScopeType
        
        // Initialize other properties to defaults or empty values
        self.photoManager = PhotoLibraryManager()
        doInitSetup()
    }
    
    deinit {
        print("In ScopeState deinit. uuid = \(uuid)")
    }
    
    init(){
//        print("In ScopeState init. uuid = \(uuid)")
        Task { @MainActor in
            try await photoManager.setupAlbumOnFirstLaunch()
        }
     doInitSetup()
    }
    
    var log: Bool = false
    
    @Published var uuid = UUID()
    

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
    // MARK: - Properties to be saved in ScopeWorks document
    var bookmarkData: Data? {
        didSet {
            guard  let bookmarkData else { return }
            var bookmarkDataIsStale: Bool = false
            do {
                imageURL = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &bookmarkDataIsStale)
            } catch {
                print("Error resolving bookmark data. error = \(error)")
            }
        }
    }
    @Published var imageURL: URL? = nil {
        didSet {
            if let imageURL {
                do {
                    let data = try Data(contentsOf: imageURL)
                    Task { @MainActor in
                        selectedImageData = data
                    }
                } catch {
                    print("Error loading image data. error = \(error)")
                }
            }
        }
    }
    
    public var document: ScopeDocument?
        
    @Published var zoom: Double = 2.0 // use a range of 1.0 to 5.0
    @Published var radiusScale: Float = 1.0
    @Published var backgroundColor = Color.white
    @Published var trianglePoints = TrianglePoints(
        point1: SIMD2<Float>(0.4, 0.25),
        point2: SIMD2<Float>(0.6, 0.25),
        point3: SIMD2<Float>(0.5, 0.42320508))
    
    @Published var rotationCenter: SIMD2<Float> = [0.5, 0.5] {
        didSet {
            //print("rotationCenter changed")
        }
    }
    @Published var showOutlines: Bool = false
    @Published var flipAlternates: Bool = true
    @Published var splitTriangle: Bool = false
    @Published var drawWithReflection: Bool = true
    @Published var animate: Bool = false
    @Published var polygonSides = 6 {
        didSet {
            trianglePoints = calcTrianglePoints()
        }
    }
    @Published var rotationSpeed: CGFloat = 10.0 // In degrees per second
    @Published var movementSpeed: CGFloat = 0 // In screen units per second.

    // MARK: - other published properties
    @Published var animateButtonTitle: String = "Animate"
    
    @Published var showOpenDialog: Bool = false

    @Published var photoManager = PhotoLibraryManager()
    @Published var showControls = true {
        didSet {
//            print("In showControls.didSet. showControls = \(showControls). uuid = \(uuid)")
        }
    }
    @Published var showSourceImage: Bool = true
    @Published var imageUUID: UUID? = nil
    @Published var isHEIC: Bool = false
    @Published var selectedImageID: String? = nil
    @Published var selectedImageData: Data? = nil {
        didSet {
            imageUUID = UUID()
        }
    }


    @Published var selectedScopeType: Int = 0

    var lastAnimationStepTime: CFTimeInterval = CACurrentMediaTime()
    @Published var texAspect: Float = 1
    @Published var texSize: CGSize = CGSize(width: 400, height: 400 )
    @Published var draggingState: DragLocations? = nil
    @Published var lastDragLocation: CGPoint? = nil
    @Published var previousRotation: Float? = nil

    
    
    @Published var firstLaunch = UserDefaults.standard.bool(forKey: "firstLaunch")
    var imageViewSize: CGSize = CGSizeZero {
        willSet {
            //print("about to change imageViewSize")
        }
        didSet {
            //print("imageViewSize = \(imageViewSize)")
        }
    }
    // DMC:
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
    
    typealias AdjustmentResult = (points: TrianglePoints, adjusted: Bool, dx: Float?, dy: Float?)
    
    func adjustTrianglePoints(trianglePoints: TrianglePoints) -> AdjustmentResult {
        let textureLimits: RangeLimits = (minX: 0, maxX: texAspect, minY: 0, maxY: 1)
        let triangleLimits = triangleLimits(trianglePoints: trianglePoints)
        var dx: Float? = nil
        var dy: Float? = nil
        //if out of range in x, calc x adjustment
        if triangleLimits.minX < textureLimits.minX {
            dx = textureLimits.minX - triangleLimits.minX
        } else if triangleLimits.maxX > textureLimits.maxX {
            dx = textureLimits.maxX - triangleLimits.maxX
        }
        if triangleLimits.minY < textureLimits.minY {
            dy = textureLimits.minY - triangleLimits.minY
        } else if triangleLimits.maxY > textureLimits.maxY {
            dy = textureLimits.maxY - triangleLimits.maxY
        }
        let adjusted = dx != nil || dy != nil
        if adjusted {
            let deltaX = dx ?? 0.0
            let deltaY = dy ?? 0.0
            let newTrianglePoints = TrianglePoints(
                point1: SIMD2<Float>(trianglePoints.point1.x + deltaX, trianglePoints.point1.y + deltaY),
                point2: SIMD2<Float>(trianglePoints.point2.x + deltaX, trianglePoints.point2.y + deltaY),
                point3: SIMD2<Float>(trianglePoints.point3.x + deltaX, trianglePoints.point3.y + deltaY))
            return (newTrianglePoints, true, dx, dy)
        }
        return (trianglePoints, false, dx, dy)
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
            
            if log {
                print("pivot: \(pivotPoint), triangleCGPoint: \n\(triangleCGPoint)")
            }
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
            if adjustment.adjusted {
                rotationCenter = rotationCenter.adjustedBy(dx: adjustment.dx ?? 0, dy: adjustment.dy ?? 0)
                rotationCenterPoint = metalPointToView(rotationCenter)
            }

        default:
            return
        }
    }
}
