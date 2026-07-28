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
import MetalKit
import UniformTypeIdentifiers
import ImageIO


enum DragLocations: String {
    case inRotationCenter
    case inTrianglePoint1
    case inTrianglePoint2
    case inTrianglePoint3
    case inTriangleBody
    case outsideTriangle
}

typealias DragPointTuple = (point: CGPoint, dragLocation: DragLocations)

enum ImageSourceMode: Equatable {
    case staticImage
    case camera(deviceID: String?)
}

struct MetalRect {
    var topLeft: simd_float2
    var topRight: simd_float2
    var bottomLeft: simd_float2
    var bottomRight: simd_float2
}

struct AspectRatio: CustomStringConvertible, Identifiable, Hashable, Equatable, Sendable {
    var id: Self { self }
    let title: String
    let width: Double
    let height: Double
    let defaultMultiplier: Int
    let index: Int
    let isCropForTiling: Bool
    nonisolated var description: String {
        return "\"\(title)\": \(width):\(height). Index = \(index)"
    }
    var cropRect: MetalRect {
        if isCropForTiling{
            // TODO: Figure out if this scope isCircular
            return  MetalRect(
                topLeft:     simd_float2(x: Float(-width / 2), y: Float( height / 2)),
                topRight:    simd_float2(x: Float( width / 2), y: Float( height / 2)),
                bottomLeft:  simd_float2(x: Float(-width / 2), y: Float(-height / 2)),
                bottomRight: simd_float2(x: Float( width / 2), y: Float(-height / 2))
            )
        }
        else {
            let aspectFactor = Float(height / width)
            return  MetalRect(
                topLeft:     simd_float2(x: Float(-1.0), y: Float( 1.0) * aspectFactor),
                topRight:    simd_float2(x: Float( 1.0), y: Float( 1.0) * aspectFactor),
                bottomLeft:  simd_float2(x: Float(-1.0), y: Float(-1.0) * aspectFactor),
                bottomRight: simd_float2(x: Float( 1.0), y: Float(-1.0) * aspectFactor)
            )
        }
    }
}


// MARK: Private vars

private var notificationTokens: [NSObjectProtocol]?

// MARK: - Persisted document properties:
// bookmarkData, imageURL, zoom, radiusScale, backgroundColor, trianglePoints,
// rotationCenter, showOutlines, flipAlternates, splitTriangle,
// drawWithReflection, animate, polygonSides,
// rotationSpeed, movementSpeed, selectedScopeType
class ScopeState: ObservableObject, Codable {
    
    @Published var availableDisplays: [DisplayInfo] = []
    @Published var selectedAspectRatio: AspectRatio
    
    var useButton: Bool = true
    
    // MARK: - Camera support (transient, not persisted)
    var cameraManager: CameraManager?
    var imageSourceMode: ImageSourceMode = .staticImage {
        didSet {
            updateImageSourceDescription()
        }
    }
    
    func updateImageSourceDescription() {
        if imageSourceMode == .staticImage {
            guard let fileName = imageSourceInfo.fullURL?.lastPathComponent else {
                imageSourceDescription = ""
                return
            }
            imageSourceDescription =  "Filename: \"\(fileName)\""
        } else {
            imageSourceDescription =  "Image source: \(cameraDescription)"
        }
        
    }
    
    // Camera textures have top-left origin; static images use bottom-left (via MTKTextureLoader)
    var cameraDescription: String = ""
    var flipTextureY: Bool = false
    
    // MARK: - Document loading state (transient, not persisted)
    /// True while a document is being loaded from file. Prevents the document
    /// from being marked dirty by initialization side-effects (texture load,
    /// triangle-point adjustment). Stays true through user-driven image
    /// relocation and is cleared when the texture is first set.
    var isLoadingFromFile = false
    
    // MARK: - External display (transient, not persisted)
    var externalDisplayViewManager: ExternalDisplayViewManager?
    weak var fullscreenMetalView: MTKView? = nil
    weak var fullscreenRenderer: ScopeRenderer? = nil
    
    weak var documentMetalView: MTKView? = nil
    weak var documentRenderer: ScopeRenderer? = nil
    
    // MARK: - Export state (transient, not persisted)
    @Published var activeRecorder: VideoRecorder? = nil
#if os(iOS)
    @Published var showExportImageSheet: Bool = false
    @Published var showRecordVideoSheet: Bool = false
    @Published var completedVideoURL: URL? = nil
    var exportSettingsState: ExportSettingsState?
#endif
    
    func updateDisplays() {
        availableDisplays = ExternalDisplayManager.availableDisplays
        if chosenDisplayID == nil {
            chosenDisplayID = availableDisplays.last?.id
        }
        
        /*
         let displays = ExternalDisplayManager.availableDisplays
         //Add code here to upate list of all aspect ratios
         allAsepectRatios = SavedAspectRatios
         for display in displays {
         guard let aspect = display.aspect else { continue }
         var found = false
         for ratio in allAsepectRatios {
         if ratio.width == aspect.width && ratio.height == aspect.height {
         found = true
         break
         }
         }
         if !found {
         allAsepectRatios.append(AspectRatio(title: display.name, width: aspect.width, height: aspect.height))
         }
         }
         for aspect in allAsepectRatios {
         print(aspect)
         }
         */
    }
    
    // MARK: - Codable Keys
    enum CodingKeys: String, CodingKey {
        case imageID
        case imageURL
        case bookmarkData
        case imageSourceInfo
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
        //        if splitTriangle {
        //            let (isRightTriangle, index) = isRightTriangle(trianglePoints)
        //            if !isRightTriangle {
        //                print("splitTriangle = true but it's not a right triangle!")
        //                splitTriangle = false
        //            }
        //        }
        //print("Adding observers")
        NotificationCenter.default.addObserver(
            forName: settingsChangedNotification,
            object: nil,
            queue: nil) { notification in
                let userInfo = notification.userInfo
                if let snapshotFileType = userInfo?[UserDefaultsKeys.snapshotFileType.rawValue] as? Int {
                    ScopeState.snapshotFileTypeIndex = snapshotFileType
                }
            }
        NotificationCenter.default.addObserver(
            forName: defaultAspectRatioChangedNotification,
            object: nil,
            queue: nil) { [weak self] notification in
                guard let userInfo = notification.userInfo,
                      let aspectRatio = userInfo["selectedAspectRatio"] as? AspectRatio else {
                    print("Invalid user info for defaultAspectRatioChangedNotification")
                    return
                }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard aspectRatio != self.selectedAspectRatio  else {
                        print("aspect ratio unchanged.")
                        return
                    }
                    print("Received changed aspectRatio \(aspectRatio)")
                    self.selectedAspectRatio = aspectRatio
                }
            }
        NotificationCenter.default.addObserver(
            forName: displaysChangedNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.availableDisplays = ExternalDisplayManager.availableDisplays
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: closingFullScreenNotification,
            object: self, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.showFullscreenView = false
            }
        }
        
        
        resolveICloudURL()
        
        // If we have an imageSourceInfo from a decoded document, resolve it now
        if imageSourceInfo.sourceType != .none && selectedImageData == nil {
            resolveImageFromSourceInfo()
        }
        availableDisplays = ExternalDisplayManager.availableDisplays
        
        // If no image will be loaded (empty document), loading is already complete
        if isLoadingFromFile && selectedImageData == nil && !needsImageRelocation {
            isLoadingFromFile = false
        }
    }
    
    /// Attempts to load the image described by imageSourceInfo.
    /// Tries bookmark → full URL → relative path from source images folder.
    /// Sets needsImageRelocation if all resolution attempts fail.
    func resolveImageFromSourceInfo() {
        defer {
            updateImageSourceDescription()
        }
        switch imageSourceInfo.sourceType {
        case .file:
            // 1. Try bookmark data (macOS security-scoped)
#if os(macOS)
            if let bmData = imageSourceInfo.bookmarkData {
                var isStale = false
                if let url = try? URL(resolvingBookmarkData: bmData,
                                      options: [.withSecurityScope],
                                      bookmarkDataIsStale: &isStale) {
                    _ = url.startAccessingSecurityScopedResource()
                    self.imageURL = url
                    return
                }
            }
#endif
            
            // 2. Try full URL
            if let url = imageSourceInfo.fullURL,
               FileManager.default.fileExists(atPath: url.path) {
                self.imageURL = url
                return
            }
            
            // 3. Try relative path from source images folder
            if let relativePath = imageSourceInfo.relativePathFromSourceImages,
               let url = FolderBookmarkManager.shared.resolveRelativePath(relativePath) {
                self.imageURL = url
                return
            }
            
            // 4. Could not resolve — search via Spotlight and flag for relocation
            print("Image not found: \(imageSourceInfo.filename ?? "unknown"). Needs relocation.")
            needsImageRelocation = true
            searchForMissingImage()
            
        case .photoLibrary:
#if os(iOS)
            if let imageID = imageSourceInfo.photoLibraryID {
                self.selectedImageID = imageID
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: [imageID], options: nil)
                if let asset = assets.firstObject {
                    PHImageManager.default().requestImageDataAndOrientation(for: asset, options: nil) { data, _, _, _ in
                        if let data { self.selectedImageData = data }
                    }
                    return
                }
            }
#endif
            // On macOS (or if photo not found on iOS), try relative path as fallback
            if let relativePath = imageSourceInfo.relativePathFromSourceImages,
               let url = FolderBookmarkManager.shared.resolveRelativePath(relativePath) {
                self.imageURL = url
                return
            }
            
            print("Photo library image not found. Needs relocation.")
            needsImageRelocation = true
            searchForMissingImage()
            
        case .bundleDefault:
            if let filename = imageSourceInfo.filename,
               let url = Bundle.main.url(forResource: filename, withExtension: nil, subdirectory: "ScopeWorks source images") {
                self.imageURL = url
                return
            }
            
        case .none:
            break
        }
    }
    
    // MARK: - Image relocation via Spotlight search
    
    /// Searches for the missing image file and shows the relocation alert.
    /// On macOS, uses Spotlight (NSMetadataQuery) to try to find the file first.
    /// On iOS, shows the alert immediately (Spotlight can't search the broad file system).
    func searchForMissingImage() {
        guard let filename = imageSourceInfo.filename else {
            postRelocationReady()
            return
        }
        
#if os(macOS)
        // Defer to main run loop — query.start() requires an active run loop,
        // and this may be called during init(from:) decoding.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            let query = NSMetadataQuery()
            query.predicate = NSPredicate(format: "%K ==[cd] %@", NSMetadataItemFSNameKey, filename)
            query.searchScopes = [
                NSMetadataQueryLocalComputerScope,
                NSMetadataQueryIndexedLocalComputerScope
            ]
            
            NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: query,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                query.stop()
                
                print("Spotlight search completed. Results: \(query.resultCount)")
                if query.resultCount > 0,
                   let item = query.result(at: 0) as? NSMetadataItem {
                    if let path = item.value(forAttribute: NSMetadataItemPathKey) as? String {
                        self.relocatedImageCandidate = URL(fileURLWithPath: path)
                        print("Spotlight found missing image at: \(path)")
                    } else if let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
                        self.relocatedImageCandidate = url
                        print("Spotlight found missing image (via URL) at: \(url.path)")
                    } else {
                        self.relocatedImageCandidate = nil
                        print("Spotlight found a result but could not extract its path")
                    }
                } else {
                    self.relocatedImageCandidate = nil
                    print("Spotlight did not find '\(filename)'")
                }
                
                self.metadataQuery = nil
                self.postRelocationReady()
            }
            
            self.metadataQuery = query
            let started = query.start()
            print("Spotlight search for '\(filename)' started: \(started)")
            
            // Fallback timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let self, self.metadataQuery != nil else { return }
                print("Spotlight search timed out for '\(filename)'")
                self.metadataQuery?.stop()
                self.metadataQuery = nil
                self.postRelocationReady()
            }
        }
#else
        // On iOS, show the alert after a brief delay so the view has time to attach.
        print("Image '\(filename)' not found. Prompting user to locate it.")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.postRelocationReady()
        }
#endif
    }
    
    private func postRelocationReady() {
        NotificationCenter.default.post(name: ScopeState.relocationReadyNotification, object: self)
    }
    
    /// Applies a user-selected or Spotlight-found image URL as the document's source image.
    /// Reads file data while security-scoped access is active, then updates all relevant state.
    func applyRelocatedImage(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        
        guard let data = try? Data(contentsOf: url) else {
            print("Failed to read relocated image data from \(url.lastPathComponent)")
            return
        }
        
        self.imageURL = url
        self.selectedImageData = data
        
#if os(macOS)
        let bmData = try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess])
#else
        let bmData = try? url.bookmarkData()
#endif
        self.bookmarkData = bmData
        
        if let typeID = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier {
            self.isHEIC = typeID == UTType.heic.identifier
        }
        
        self.imageSourceInfo = .fromFile(url: url, bookmarkData: bmData)
        self.needsImageRelocation = false
        self.relocatedImageCandidate = nil
        
        self.switchToStaticImage()
    }
    
    // MARK: - Initializer for decoding
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try new-format imageSourceInfo first; fall back to legacy fields
        if let info = try container.decodeIfPresent(ImageSourceInfo.self, forKey: .imageSourceInfo),
           info.sourceType != .none {
            self.imageSourceInfo = info
            // Defer image resolution to after all properties are set (called below via doInitSetup)
        } else {
            // Legacy fallback: read old bookmarkData / imageURL / imageID fields
            // and backfill imageSourceInfo
#if os(macOS)
            self.bookmarkData = try container.decodeIfPresent(Data.self, forKey: .bookmarkData)
            if let data = self.bookmarkData {
                var bookmarkDataIsStale: Bool = false
                do {
                    let resolvedURL = try URL(resolvingBookmarkData: data,
                                              options: .withSecurityScope,
                                              bookmarkDataIsStale: &bookmarkDataIsStale)
                    _ = resolvedURL.startAccessingSecurityScopedResource()
                    self.imageURL = resolvedURL
                } catch {
                    print("Error loading bookmark: \(error)")
                }
            }
            self.selectedAspectRatio = AspectRatio(
                title: "16:9",
                width: 16,
                height: 9,
                defaultMultiplier: 120,
                index: 5,
                isCropForTiling: false)
            if self.imageURL == nil {
                self.imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
            }
            // Backfill imageSourceInfo from legacy fields
            if let url = self.imageURL {
                self.imageSourceInfo = .fromFile(url: url, bookmarkData: self.bookmarkData)
            }
#else
            self.selectedAspectRatio = AspectRatio(
                title: "16:9",
                width: 16,
                height: 9,
                defaultMultiplier: 120,
                index: 5,
                isCropForTiling: false)
            if let imageID = try? container.decodeIfPresent(String.self, forKey: .imageID) {
                print("in ScopeState.init(from:), found imageID: \(imageID)")
                self.selectedImageID = imageID
                self.imageSourceInfo = .fromPhotoLibrary(id: imageID)
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
        }
        
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
        var tempSplit = try container.decode(Bool.self, forKey: .splitTriangle)
        var isRight: Bool = false
        if tempSplit {
            (isRight, _) = isRightTriangle(trianglePoints)
        }
        if tempSplit && !isRight {
            print("splitTriangle == true but triangle is not a right triangle. Fixing.")
        }
        self.splitTriangle = tempSplit && isRight
        self.drawWithReflection = try container.decode(Bool.self, forKey: .drawWithReflection)
        self.animate = false //try container.decode(Bool.self, forKey: .animate)
        //        self.showControls = try container.decode(Bool.self, forKey: .showControls)
        self.rotationSpeed = try container.decode(CGFloat.self, forKey: .rotationSpeed)
        self.movementSpeed = try container.decode(CGFloat.self, forKey: .movementSpeed)
        self.selectedScopeType = try container.decode(Int.self, forKey: .selectedScopeType)
        
        // Set default values for properties not persisted
        self.photoManager = PhotoLibraryManager()
        self.selectedAspectRatio = AspectRatio(
            title: "16:9",
            width: 16,
            height: 9,
            defaultMultiplier: 120,
            index: 5,
            isCropForTiling: false)
        
        self.isLoadingFromFile = true
        
        doInitSetup()
        
        //print("In ScopeState init.from. uuid = \(uuid)")
    }
    
    // MARK: - Encode
    func encode(to encoder: Encoder) throws {
        //print("----------------------")
        //print("In ScopeState.encode. selectedImageID = \(selectedImageID)")
        //print("trianglePoints = \(trianglePoints)")
        //print("----------------------")
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // New format
        try container.encode(imageSourceInfo, forKey: .imageSourceInfo)
        // Legacy fields for backward compat with older app versions
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
        self.selectedAspectRatio = AspectRatio(
            title: "16:9",
            width: 16,
            height: 9,
            defaultMultiplier: 120,
            index: 5,
            isCropForTiling: false)
        
        doInitSetup()
    }
    
    deinit {
        //print("In ScopeState deinit. uuid = \(uuid)")
    }
    
    init(){
        //        print("In ScopeState init. uuid = \(uuid)")
        self.selectedAspectRatio = AspectRatio(
            title: "16:9",
            width: 16,
            height: 9,
            defaultMultiplier: 120,
            index: 5,
            isCropForTiling: false)
        
        Task { @MainActor in
            try await photoManager.setupAlbumOnFirstLaunch()
        }
        
        doInitSetup()
    }
    
    // MARK: - Camera lifecycle
    func startCamera(deviceID: String? = nil) async {
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        if cameraManager == nil {
            cameraManager = CameraManager(metalDevice: device, scopeState: self)
        }
        imageSourceMode = .camera(deviceID: deviceID)
        flipTextureY = true
        await cameraManager?.startCamera(deviceID: deviceID)
    }
    
    func stopCamera() {
        cameraManager?.stopCamera()
        imageSourceMode = .staticImage
        flipTextureY = false
    }
    
    func switchToStaticImage() {
        stopCamera()
        // Restore the static image texture if we have image data
        if selectedImageData != nil {
            imageUUID = UUID()
        }
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
    
    
    @Published var showCropRect: Bool = false
    @Published var showFullscreenView: Bool = false {
        didSet {
            if showFullscreenView == false {
                externalDisplayViewManager?.selectedDisplayID = nil
            } else {
                externalDisplayViewManager?.selectedDisplayID = chosenDisplayID
            }
        }
    }
    
    @Published var chosenDisplayID: String? = nil {
        didSet {
            if showFullscreenView {
                externalDisplayViewManager?.selectedDisplayID = chosenDisplayID
            }
        }
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
                    selectedImageData = data
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
    var trianglePoints = TrianglePoints(
        point1: SIMD2<Float>(0.4, 0.25),
        point2: SIMD2<Float>(0.6, 0.25),
        point3: SIMD2<Float>(0.5, 0.42320508))
    
    var rotationCenter: SIMD2<Float> = [0.5, 0.5] {
        didSet {
            //print("rotationCenter changed")
        }
    }
    @Published var showOutlines: Bool = false
    @Published var flipAlternates: Bool = true
    @Published var splitTriangle: Bool = false {
        //splitTriangle didSet
        didSet {
            if splitTriangle {
                let midpoint = midpoint(p1: trianglePoints.point2, p2: trianglePoints.point3)
                trianglePoints = TrianglePoints(point1: trianglePoints.point1, point2: midpoint, point3: trianglePoints.point3)
            } else {
                let distance = simd_float2(x: trianglePoints.point2.x - trianglePoints.point3.x, y: trianglePoints.point2.y - trianglePoints.point3.y)
                let point2 = trianglePoints.point3 + distance * 2.0
                trianglePoints = TrianglePoints(point1: trianglePoints.point1, point2: point2, point3: trianglePoints.point3)
                //trianglePoints = calcTrianglePoints(typeChanged: false)
                (trianglePoints, _, _, _) = adjustTrianglePoints(trianglePoints: trianglePoints)
                
                
            }
        }
    }
    @Published var drawWithReflection: Bool = true {
        didSet {
            print("In drawWithReflection.didSet")
        }
    }
    //    @Published var splitPolygonTriangles: Bool = false {
    //        didSet {
    //            if splitPolygonTriangles {
    //                let midpoint = midpoint(p1: trianglePoints.point2, p2: trianglePoints.point3)
    //                trianglePoints = TrianglePoints(point1: trianglePoints.point1, point2: midpoint, point3: trianglePoints.point3)
    //            } else {
    //                let distance = simd_float2(x: trianglePoints.point2.x - trianglePoints.point3.x, y: trianglePoints.point2.y - trianglePoints.point3.y)
    //                let point2 = trianglePoints.point3 + distance * 2.0
    //                trianglePoints = TrianglePoints(point1: trianglePoints.point1, point2: point2, point3: trianglePoints.point3)
    //                trianglePoints = calcTrianglePoints(typeChanged: false)
    //
    //
    //            }
    /*
     if (splitPolygonTriangles) {
     point2 = GLMakePoint((point2.x+point3.x)/2, (point2.y+point3.y)/2);
     } else {
     //TODO: Fix point2 if it is now out of bounds
     point2 = GLMakePoint((point2.x-point3.x)*2 + point3.x, (point2.y-point3.y)*2+ point3.y);
     [self adjustRoationAndShiftToScale];
     }
     
     */
    @Published var animate: Bool = false
    @Published var polygonSides = 6 {
        didSet {
            trianglePoints = calcTrianglePoints(typeChanged: false)
        }
    }
    @Published var rotationSpeed: CGFloat = 5.0 // In degrees per second
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
    
    /// Consolidated image source metadata, persisted in each .KSp2 document.
    var imageSourceInfo = ImageSourceInfo() {
        didSet {
            print("In ScopeState.imageSourceInfo.didSet")
        }
    }
    @Published var imageSourceDescription: String = ""
    
    
    
    /// Set to true when a document's image could not be resolved and needs user help.
    var needsImageRelocation = false
    /// URL found by Spotlight search, if any. Used to pre-navigate the file picker.
    var relocatedImageCandidate: URL?
    /// Retained NSMetadataQuery for Spotlight file search.
    private var metadataQuery: NSMetadataQuery?
    
    /// Notification posted when the relocation search finishes and the alert should be shown.
    static let relocationReadyNotification = Notification.Name("ScopeStateRelocationReady")
    
    
    @Published var selectedScopeType: Int = 1 {
        didSet {
            trianglePoints = calcTrianglePoints(typeChanged: true)
        }
    }
    
    var lastAnimationStepTime: CFTimeInterval = CACurrentMediaTime()
    @Published var texAspect: Float = 1
    @Published var texSize: CGSize = CGSize(width: 400, height: 400 )
    @Published var draggingState: DragLocations? = nil
    @Published var lastDragLocation: CGPoint? = nil
    @Published var previousRotation: Float? = nil
    
    
    
    @Published var firstLaunch = UserDefaults.standard.bool(forKey: "firstLaunch")
    
    var aspectAdjustment: CGSize = .zero
    var imageViewSize: CGSize = CGSizeZero {
        willSet {
            //print("about to change imageViewSize")
        }
        didSet {
            //print("imageViewSize = \(imageViewSize)")
        }
    }
    // DMC:
    var texture: MTLTexture? {
        didSet {
            guard let texture else { return }
            let texWidth = CGFloat(texture.width)
            let texHeight = CGFloat(texture.height)
            let newSize = CGSize(width: texWidth, height: texHeight)
            guard newSize != texSize else { return }
            // Only fire objectWillChange when dimensions actually change
            objectWillChange.send()
            // trianglePoints = calcTrianglePoints(typeChanged: false)
            texSize = newSize
            texAspect = Float(texWidth / texHeight)
            if texAspect > 1 {
                aspectAdjustment.width = texWidth / texHeight
                aspectAdjustment.height = 1.0
            } else {
                aspectAdjustment.width = texWidth / texHeight
                aspectAdjustment.height = 1.0
            }
            // Make sure the triangle fits inside the texture bounds and adjust if not.
            // Skip during initial document load — saved triangle points are already
            // valid for the saved texture. Adjusting here would modify a CodingKeys
            // property and mark the document dirty on open.
            if isLoadingFromFile {
                isLoadingFromFile = false
            } else {
                (trianglePoints, _, _, _) = adjustTrianglePoints(trianglePoints: trianglePoints)
            }
        }
    }
    
    private var trianglePoint1: CGPoint = CGPointZero
    private var trianglePoint2: CGPoint = CGPointZero
    private var trianglePoint3: CGPoint = CGPointZero
    private var rotationCenterPoint: CGPoint = CGPointZero
    
    typealias AdjustmentResult = (points: TrianglePoints, adjusted: Bool, dx: Float?, dy: Float?)
    
    // MARK: Misc functions -
    
    func selectNextFullScreenDisplay() {
        //availableDisplays
        guard let currentIndex = availableDisplays.firstIndex(where:  { $0.id == chosenDisplayID }) else {
            return
        }
        let nextIndex = (currentIndex + 1) % availableDisplays.count
        chosenDisplayID = availableDisplays[nextIndex].id
    }
    
    func animateByElapsed(_ elapsed: Double) {
        
        let degrees = Float(elapsed * Double(rotationSpeed))
        let radians = degrees.degreesToRadians
        let changed = rotateTriangle(trianglePoints: trianglePoints, angle: radians, aroundCenter: rotationCenter)
        let adjustment = adjustTrianglePoints(trianglePoints: changed)
        trianglePoints = adjustment.points
        if adjustment.adjusted {
            rotationCenter = rotationCenter.adjustedBy(dx: adjustment.dx ?? 0, dy: adjustment.dy ?? 0)
        }
    }
    
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
    
    func calcTrianglePoints(typeChanged: Bool) -> TrianglePoints {
        //print("Entering function \(#function)")
        guard selectedImageData != nil || imageSourceMode != .staticImage else {
            return TrianglePoints(
                point1: SIMD2<Float>(0.4, 0.25),
                point2: SIMD2<Float>(0.6, 0.25),
                point3: SIMD2<Float>(0.5, 0.42320508))
        }
        let template: ScopeTemplate = ScopeWorks2App.scopeTemplates[selectedScopeType]
        
        guard template.isCircular || typeChanged else {
            return trianglePoints
        }
        var result: TrianglePoints
        let oldMidpoint: SIMD2<Float>
        if splitTriangle {
            oldMidpoint = trianglePoints.point2
        } else {
            oldMidpoint = midpoint(p1: trianglePoints.point2, p2: trianglePoints.point3)
        }
        let point1 = trianglePoints.point1
        let centerAngle = atan2(Double(oldMidpoint.y - point1.y), Double(oldMidpoint.x - point1.x) )
        
        
        if template.isCircular {
            
            let stepArc = Double.pi / Double(polygonSides)
            let radius = max(distanceBetween(p1: trianglePoints.point1, p2: trianglePoints.point2),
                             distanceBetween(p1: trianglePoints.point1, p2: trianglePoints.point3) )
            
            var deltaY = Float(sin(centerAngle + stepArc)) * radius
            var deltaX = Float(cos(centerAngle + stepArc)) * radius
            let point3 = SIMD2<Float>(point1[0] + deltaX, point1[1] + deltaY)
            deltaY = Float(sin(centerAngle - stepArc)) * radius
            deltaX = Float(cos(centerAngle - stepArc)) * radius
            var point2 = SIMD2<Float>(point1.x + deltaX, point1.y + deltaY)
            if splitTriangle {
                let newMidpoint = midpoint(p1: point2, p2: point3)
                point2 = newMidpoint
            }
            
            result = TrianglePoints(point1: point1, point2: point2, point3: point3)
        } else {
            // 8-way square
            let point3Angle = centerAngle + .pi / 8
            let newLength = max(
                distanceBetween(p1: trianglePoints.point1, p2: trianglePoints.point2),
                distanceBetween(p1: trianglePoints.point1, p2: trianglePoints.point3) )
            let point3 = point1 + simd_float2(
                x: Float(cos(point3Angle)) * newLength,
                y: Float(sin(point3Angle)) * newLength)
            let point2Distance = newLength * sqrt(2) / 2
            let point2Angle = centerAngle - .pi / 8
            let point2 = point1 + simd_float2(
                x: Float(cos(point2Angle)) * point2Distance,
                y: Float(sin(point2Angle)) * point2Distance)
            result =  TrianglePoints(point1: point1, point2: point2, point3: point3)
            
            
        }
        (result, _, _, _) = adjustTrianglePoints(trianglePoints: result)
        
        return result
    }
    
    func metalPointToView(_ metalPoint: SIMD2<Float>) -> CGPoint {
        return CGPoint(
            x: CGFloat(metalPoint.x.interpolated(from: 0...1, to: 0...Float(imageViewSize.width)) * 1),
            y: (imageViewSize.height - CGFloat(metalPoint.y.interpolated(from: 0...1, to: 0...Float(imageViewSize.height)) )) * CGFloat(1))
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
        //        let aspect = imageViewSize.width / imageViewSize.height
        let adjusted = CGPoint(x: startLocation.x * aspectAdjustment.width, y: startLocation.y * aspectAdjustment.height)
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
    
    
    func snapshotImage(isFullscreenView: Bool) -> CGImage? {
        guard let metalView = isFullscreenView ? self.fullscreenMetalView : documentMetalView else { return nil
        }
        if isFullscreenView {
            guard let drawableTexture = metalView.currentDrawable?.texture else { return nil }
            
            //TODO: For the document metal view, set the drawable size to a size for the current crop rect
            
            let ciContext = CIContext()
            // The texture format is .bgra8Unorm (not _srgb), so the framebuffer stores
            // sRGB-encoded values without automatic conversion. Tell CIImage the values
            // are sRGB to prevent a double gamma curve that washes out colors.
            guard let ciImage = CIImage(mtlTexture: drawableTexture, options: [
                .colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
            ]) else {
                return nil
            }
            
            let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
            return ciContext.createCGImage(ciImage, from: ciImage.extent,
                                           format: .RGBA8, colorSpace: sRGB)
        } else {
            guard let renderer = self.documentRenderer else {
                print("Renderer not available for off-screen rendering")
                return nil
            }
            guard let image = renderer.renderOffscreenImage(
                width: Int(selectedAspectRatio.width * Double(selectedAspectRatio.defaultMultiplier)),

                height: Int(selectedAspectRatio.height * Double(selectedAspectRatio.defaultMultiplier)),
                aspectRatio: selectedAspectRatio
            ) else {
                print("Off-screen render failed")
                return nil
            }
            return image
        }
    }
    /// Cached iCloud Documents URL, resolved once on a background queue at startup.
    private var _iCloudDocumentsURL: URL?
    private var _iCloudURLResolved = false
    
    /// Resolves the iCloud ubiquity container on a background queue and caches the result.
    /// Must be called early (e.g. from doInitSetup).
    private func resolveICloudURL() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            // This call can block — Apple requires it off the main thread.
            let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)
            let documentsURL = containerURL?.appendingPathComponent("Documents")
            
            // Ensure the Documents subdirectory exists inside the container
            if let documentsURL {
                try? FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
            }
            
            DispatchQueue.main.async {
                self?._iCloudDocumentsURL = documentsURL
                self?._iCloudURLResolved = true
                if let documentsURL {
                    //print("iCloud container resolved: \(documentsURL.path)")
                } else {
                    print("iCloud container not available")
                }
            }
        }
    }
    
    /// Returns the shared iCloud ubiquity container Documents URL.
    /// Both Mac and iOS use the same container so files sync across devices.
    private var iCloudDocumentsURL: URL? {
        return _iCloudDocumentsURL
    }
    
    func saveSnapshotImage(_ image: CGImage, autoSaveToiCloud: Bool = true) {
        
        guard let filetype = Self.snapshotFileType else {
            print("Unknown file type")
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy'@'hh.mm.ss a"
        let timestamp = formatter.string(from: Date())
        let defaultFilename = "ScopeWorks snapshot \(timestamp)"
        let fileExtension = filetype.preferredFilenameExtension ?? "png"
        let filename = "\(defaultFilename).\(fileExtension)"
        
        if autoSaveToiCloud {
            // Both platforms: use a security-scoped bookmark so files go to the
            // user-visible iCloud Drive folder. Prompts once on first use.
            autoSaveToBookmarkedFolder(image: image, filename: filename, filetype: filetype)
        } else {
            // Manual save: show a save panel (macOS) or document picker (iOS).
            showSavePanel(image: image, defaultFilename: defaultFilename, directoryURL: nil, filetype: filetype)
        }
    }
    
    // MARK: - Auto-save using FolderBookmarkManager
    
    /// Auto-saves to the "ScopeWorks images" folder configured during first launch.
    /// Falls back to a save panel if the snapshots folder bookmark is unavailable.
    private func autoSaveToBookmarkedFolder(image: CGImage, filename: String, filetype: UTType) {
        let manager = FolderBookmarkManager.shared
        
        if let snapshotsURL = manager.snapshotsURL {
            let accessing = snapshotsURL.startAccessingSecurityScopedResource()
            defer { if accessing { snapshotsURL.stopAccessingSecurityScopedResource() } }
            
            let fileURL = snapshotsURL.appendingPathComponent(filename)
            writeImage(image, to: fileURL, type: filetype)
        } else {
            // Snapshots folder not configured — fall back to save panel
            print("Snapshots folder not configured — falling back to save panel")
            let defaultFilename = (filename as NSString).deletingPathExtension
            showSavePanel(image: image, defaultFilename: defaultFilename, directoryURL: nil, filetype: filetype)
        }
    }
    
    // MARK: - Export directory tracking

    /// Returns the last directory the user saved an export to, resolved from a
    /// security-scoped bookmark stored in UserDefaults. Falls back to the
    /// FolderBookmarkManager snapshots folder.
    private var lastUsedExportDirectory: URL? {
        if let data = UserDefaults.standard.data(
            forKey: UserDefaultsKeys.lastUsedExportDirectoryBookmark.rawValue
        ) {
            var isStale = false
            #if os(macOS)
            let opts: URL.BookmarkResolutionOptions = [.withSecurityScope]
            #else
            let opts: URL.BookmarkResolutionOptions = []
            #endif
            if let url = try? URL(resolvingBookmarkData: data, options: opts,
                                  bookmarkDataIsStale: &isStale) {
                #if os(macOS)
                _ = url.startAccessingSecurityScopedResource()
                #endif
                return url
            }
        }
        return FolderBookmarkManager.shared.snapshotsURL
    }

    /// Saves a bookmark for the directory the user just exported to.
    private func saveLastUsedExportDirectory(_ dirURL: URL) {
        #if os(macOS)
        let data = try? dirURL.bookmarkData(options: [.withSecurityScope])
        #else
        let data = try? dirURL.bookmarkData()
        #endif
        if let data {
            UserDefaults.standard.set(data,
                forKey: UserDefaultsKeys.lastUsedExportDirectoryBookmark.rawValue)
        }
    }

    func showSavePanel(image: CGImage, defaultFilename: String, directoryURL: URL?, filetype: UTType) {
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [filetype]
        savePanel.nameFieldStringValue = defaultFilename
        savePanel.directoryURL = directoryURL ?? lastUsedExportDirectory
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                self.writeImage(image, to: url, type: filetype)
                self.saveLastUsedExportDirectory(url.deletingLastPathComponent())
            }
        }
        #elseif os(iOS)
        let fileExtension = filetype.preferredFilenameExtension ?? "png"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(defaultFilename).\(fileExtension)")
        writeImage(image, to: tempURL, type: filetype)
        
        let picker = UIDocumentPickerViewController(forExporting: [tempURL])
        picker.directoryURL = directoryURL ?? lastUsedExportDirectory
        
        // Present on the key window's view controller. This ensures the picker
        // appears above any full-screen overlay window (which has an elevated windowLevel).
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
    
    @discardableResult
    private func writeImage(_ image: CGImage, to url: URL, type: UTType) -> Bool {
        // Encode image data in memory, then write to disk.
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData, type.identifier as CFString, 1, nil
        ) else {
            print("Failed to create image destination for type \(type.identifier)")
            return false
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            print("Failed to finalize image data")
            return false
        }
        
        do {
            try (data as Data).write(to: url)
            print("Saved snapshot to \(url.path)")
            return true
        } catch {
            print("Failed to write image to \(url.path): \(error.localizedDescription)")
            return false
        }
    }
    
    func recordVideo() {
        #if os(macOS)
        let template: ScopeTemplate = ScopeWorks2App.scopeTemplates[selectedScopeType]
        let settings = ExportSettingsState(
            defaultAspectRatio: selectedAspectRatio,
            isEightWayScope:  !template.isCircular)
        let accessoryView = NSHostingView(rootView: ExportSettingsView(settings: settings, isForVideo: true))
        accessoryView.frame = NSRect(x: 0, y: 0, width: 350, height: 170)

        let savePanel = NSSavePanel()
        savePanel.accessoryView = accessoryView
        savePanel.allowedContentTypes = [.quickTimeMovie, .mpeg4Movie]
        savePanel.nameFieldStringValue = "ScopeWorks recording"
        savePanel.directoryURL = lastUsedExportDirectory

        // Reject the Save action (with an explanatory alert) while the requested
        // size exceeds what the H.264 encoder accepts. The delegate property is
        // weak, so keep a strong reference until the panel completes.
        let sizeValidator = ExportSizeValidator(settings: settings, isForVideo: true)
        savePanel.delegate = sizeValidator

        savePanel.begin { [weak self] result in
            _ = sizeValidator // keep the delegate alive for the panel's lifetime
            guard result == .OK, let url = savePanel.url, let self else { return }
            guard let renderer = self.documentRenderer else {
                print("Renderer not available for video recording")
                return
            }

            // Safety net — the panel delegate should have blocked this already.
            guard !settings.exceedsMaxVideoSize else {
                print("Video size exceeds the H.264 encoder limit")
                return
            }

            // Record to a temp file, then move to the user's chosen destination on stop.
            // This avoids sandbox permission issues when overwriting existing files.
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "." + url.pathExtension)

            let recorder = VideoRecorder(
                width: settings.exportWidth,
                height: settings.exportHeight,
                outputURL: tempURL,
                renderer: renderer,
                aspectRatio: settings.selectedAspectRatio
            )
            recorder.destinationURL = url
            self.saveLastUsedExportDirectory(url.deletingLastPathComponent())

            do {
                try recorder.setup()
                self.activeRecorder = recorder
            } catch {
                print("Failed to set up video recorder: \(error)")
            }
        }
        #elseif os(iOS)
        let template: ScopeTemplate = ScopeWorks2App.scopeTemplates[selectedScopeType]
        exportSettingsState = ExportSettingsState(
            defaultAspectRatio: selectedAspectRatio,
            isEightWayScope: !template.isCircular)
        showRecordVideoSheet = true
        #endif
    }
    
    static func getMaxTextureSize() -> Int {
       let device = MTLCreateSystemDefaultDevice()!
       
       // According to the Metal Feature Set Tables there are only two supported maximum resolutions
       // 16384px for macs and the latest iOS devices
       // 8192px for the older iOS devices
       // Older Apple devices used to be limited to 4,096, 2,048 or even 1,024, but are no longer supported
       // https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf
       
       if device.supportsFamily(MTLGPUFamily.mac2) ||
          device.supportsFamily(MTLGPUFamily.apple3) {
          return 16384
       }
       
       return 8192
    }

    func saveImageAs() {
        #if os(macOS)
        let template: ScopeTemplate = ScopeWorks2App.scopeTemplates[selectedScopeType]

        let settings = ExportSettingsState(
            defaultAspectRatio: selectedAspectRatio,
            isEightWayScope: !template.isCircular)
        let accessoryView = NSHostingView(rootView: ExportSettingsView(settings: settings, isForVideo: false))
        accessoryView.frame = NSRect(x: 0, y: 0, width: 350, height: 210)

        let savePanel = NSSavePanel()
        savePanel.accessoryView = accessoryView
        savePanel.allowedContentTypes = [settings.selectedFormat.fileType].compactMap { $0 }
        savePanel.directoryURL = lastUsedExportDirectory

        // Reject the Save action (with an explanatory alert) while the requested
        // size exceeds the GPU's maximum texture size. The delegate property is
        // weak, so keep a strong reference until the panel completes.
        let sizeValidator = ExportSizeValidator(settings: settings)
        savePanel.delegate = sizeValidator

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy'@'hh.mm.ss a"
        let timestamp = formatter.string(from: Date())
        savePanel.nameFieldStringValue = "ScopeWorks image \(timestamp)"

        // Keep allowed content types in sync with the format picker
        var formatCancellable: AnyCancellable?
        formatCancellable = settings.$selectedFormat.sink { format in
            if let fileType = format.fileType {
                savePanel.allowedContentTypes = [fileType]
            }
            _ = formatCancellable // prevent premature deallocation
        }

        savePanel.begin { [weak self] result in
            formatCancellable?.cancel()
            _ = sizeValidator // keep the delegate alive for the panel's lifetime
            guard result == .OK, let url = savePanel.url, let self else { return }
            // xxx
            guard let renderer = self.documentRenderer else {
                print("Renderer not available for off-screen rendering")
                return
            }
            guard let filetype = settings.selectedFormat.fileType else { return }

            // Safety net — the panel delegate should have blocked this already.
            guard !settings.exceedsMaxTextureSize else {
                print("Texture can't be wider/taller than \(settings.maxTextureSize)")
                return
            }
            
            guard let image = renderer.renderOffscreenImage(
                width: settings.exportWidth,
                height: settings.exportHeight,
                aspectRatio: settings.selectedAspectRatio
            ) else {
                print("Off-screen render failed")
                return
            }

            self.writeImage(image, to: url, type: filetype)
            self.saveLastUsedExportDirectory(url.deletingLastPathComponent())
        }
        #elseif os(iOS)
        let template: ScopeTemplate = ScopeWorks2App.scopeTemplates[selectedScopeType]
        exportSettingsState = ExportSettingsState(
            defaultAspectRatio: selectedAspectRatio,
            isEightWayScope: !template.isCircular)
        showExportImageSheet = true
        #endif
    }
    func handleSnapshot(isFullScreenView: Bool) {
        /*
         weak var documentMetalView: MTKView? = nil
         weak var fullscreenMetalView: MTKView? = nil

         */
        guard  (isFullScreenView ? fullscreenMetalView : documentMetalView) != nil else {
            print("In \(#function), metalView = nil")
            return
        }
        print("Snapshot button pressed.")
        guard let snapshotImage = snapshotImage(isFullscreenView: isFullScreenView) else {
            print("snapshotImage returned nil")
            return
        }
        saveSnapshotImage(snapshotImage)
    }
    
    static var snapshotFileType: UTType? {
        SnapshotFormat.allCases[Self.snapshotFileTypeIndex].fileType
    }
    
    static  var snapshotFileTypeIndex: Int = Int(UserDefaults.standard.integer(forKey: UserDefaultsKeys.snapshotFileType.rawValue))

}

#if os(macOS)
/// Save panel delegate that rejects the Save action while the requested export size
/// exceeds the GPU's maximum texture size. Throwing from `panel(_:validate:)` shows
/// an alert and keeps the panel open so the user can correct the dimensions.
private class ExportSizeValidator: NSObject, NSOpenSavePanelDelegate {
    let settings: ExportSettingsState
    let isForVideo: Bool

    init(settings: ExportSettingsState, isForVideo: Bool = false) {
        self.settings = settings
        self.isForVideo = isForVideo
    }

    func panel(_ sender: Any, validate url: URL) throws {
        if isForVideo {
            if settings.exceedsMaxVideoSize {
                let maxSize = settings.maxVideoSize
                throw NSError(
                    domain: "ScopeWorks2",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "The video size is too large.",
                        NSLocalizedRecoverySuggestionErrorKey:
                            "The maximum video size for this aspect ratio is \(maxSize.width)×\(maxSize.height) px."
                    ]
                )
            }
        } else if settings.exceedsMaxTextureSize {
            throw NSError(
                domain: "ScopeWorks2",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "The image size is too large.",
                    NSLocalizedRecoverySuggestionErrorKey:
                        "Maximum texture width/height is \(settings.maxTextureSize) px."
                ]
            )
        }
    }
}
#endif


