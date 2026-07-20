import MetalKit
import simd
import SwiftUI
import ImageIO
import CoreImage

#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

/// If the image needs color space conversion or orientation normalization, returns
/// new PNG data in sRGB with "up" orientation. Returns nil when no conversion is needed
/// (image is already sRGB with correct orientation), so the caller can use the original data.
/// Untagged images are assumed to be sRGB.
func sRGBImageData(from imageData: Data) -> Data? {
    guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
          let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        return nil
    }

    let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    // Read EXIF orientation metadata
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    let orientationRaw = properties?[kCGImagePropertyOrientation] as? UInt32
    let orientation = orientationRaw.flatMap { CGImagePropertyOrientation(rawValue: $0) } ?? .up

    // Determine whether conversion is needed
    let sourceColorSpace = cgImage.colorSpace
    let isSRGB = (sourceColorSpace == nil) || (sourceColorSpace?.name == CGColorSpace.sRGB)
    let needsOrientationFix = orientation != .up

    if isSRGB && !needsOrientationFix {
        return nil  // No conversion needed — caller should use original data
    }

    // Use CIImage for color space conversion and/or orientation normalization
    var ciImage = CIImage(cgImage: cgImage)
    if needsOrientationFix {
        ciImage = ciImage.oriented(forExifOrientation: Int32(orientation.rawValue))
    }

    let context = CIContext()
    guard let convertedImage = context.createCGImage(ciImage, from: ciImage.extent,
                                                     format: .RGBA8, colorSpace: sRGBColorSpace) else {
        return nil
    }

    // Encode as PNG for reliable loading by MTKTextureLoader
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        data as CFMutableData, "public.png" as CFString, 1, nil
    ) else { return nil }
    CGImageDestinationAddImage(destination, convertedImage, nil)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return data as Data
}

extension Float {
    var degreesToRadians: Float {
        return self * .pi / 180
    }
}

public struct TriangleCGPoints: CustomStringConvertible{
    let point1: CGPoint
    let point2: CGPoint
    let point3: CGPoint
    
    public var description: String {
        return """
            point1: \(point1)
            point2: \(point2)
            point3: \(point3)
            """
    }
}

public struct TrianglePoints: CustomStringConvertible{
    let point1: SIMD2<Float>
    let point2: SIMD2<Float>
    let point3: SIMD2<Float>
    
    public var description: String {
        return """
            point1: \(point1.myDescription)
            point2: \(point2.myDescription)
            point3: \(point3.myDescription)
            """
    }
}



let red: SIMD4<Float> = SIMD4<Float>(1, 0, 0, 1)
let yellow: SIMD4<Float> = SIMD4<Float>(1, 1, 0, 1)
let blue: SIMD4<Float> = SIMD4<Float>(0, 0, 1, 1)
let black: SIMD4<Float> = SIMD4<Float>(0, 0, 0, 1)
let white: SIMD4<Float> = SIMD4<Float>(1, 1, 1, 1)
let zeroPoint = simd_float2(0,0)

class ScopeRenderer: NSObject, MTKViewDelegate {
    
    var isMainDocumentScopeView: Bool
    var scale: Float = 1.0
    
    var sampleCount: Int = 1
    var imageUUID: UUID? = nil
    static var logPoints: Bool = false
    weak var mtkView: MTKView?
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var pipeline: MTLRenderPipelineState!
    
    
    var scopeState: ScopeState
    // Track current drawable size for orientation handling
    private(set) var drawableSize: CGSize = .zero
    
    struct Uniforms {
        let color: simd_float4          //Only used for drawwingwith colors
        let drawWithTetxure: Bool
        let drawTextureTriangles: Bool
        let textureTriangle: TrianglePoints
        let texAspect: Float
        let orthoMatrix: float4x4
        let flipTextureY: Bool
    }
    
#if os(iOS)
    init(scopeState: ScopeState, isMainDocumentScopeView: Bool) {
        self.scopeState = scopeState
        self.isMainDocumentScopeView = isMainDocumentScopeView
        super.init()
        device = MTLCreateSystemDefaultDevice()
        if device.supportsTextureSampleCount(4) {
            sampleCount = 4
        } else if device.supportsTextureSampleCount(2) {
            sampleCount = 2
        }
        commandQueue = device.makeCommandQueue()
        makePipeline()
        loadTexture()
    }
#elseif os(macOS)
    init(scopeState: ScopeState, isMainDocumentScopeView: Bool) {
        self.scopeState = scopeState
        self.isMainDocumentScopeView = isMainDocumentScopeView
        super.init()
        device = MTLCreateSystemDefaultDevice()
        // xxx
        if device.supportsTextureSampleCount(4) {
            sampleCount = 4
        } else if device.supportsTextureSampleCount(2) {
            sampleCount = 2
        }
        commandQueue = device.makeCommandQueue()
        makePipeline()
        loadTexture()
    }
#endif
    
    
    
    func makePipeline() {
        let library = device.makeDefaultLibrary()
        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.vertexFunction = library?.makeFunction(name: "vertex_main")
        pipelineDesc.fragmentFunction = library?.makeFunction(name: "fragment_main")
        pipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Enable blending for transparent drawing
        pipelineDesc.rasterSampleCount = sampleCount // xxx
        pipelineDesc.colorAttachments[0].isBlendingEnabled = true
        pipelineDesc.colorAttachments[0].rgbBlendOperation = .add
        pipelineDesc.colorAttachments[0].alphaBlendOperation = .add
        pipelineDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDesc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        pipeline = try! device.makeRenderPipelineState(descriptor: pipelineDesc)
    }
    
    func updateImageData() {
        // Skip if in camera mode -- CameraManager updates texture directly
        guard scopeState.imageSourceMode == .staticImage else { return }
        if true {
            if let scopeImageUUID = scopeState.imageUUID,
               imageUUID != scopeImageUUID {
                //print("New image, UUID = \(scopeImageUUID), reloading texture")
                loadTexture()
                imageUUID = scopeState.imageUUID
            }
        }
    }
    
    func loadTexture() {
        guard let imageData = scopeState.selectedImageData else { return }
        let loader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [
            .origin: MTKTextureLoader.Origin.bottomLeft,
            .generateMipmaps: true,
            .SRGB: false
        ]
        
        do {
            // Convert to sRGB if needed; otherwise use the original data directly.
            // Always go through newTexture(data:) which handles all image formats reliably.
            let textureData = sRGBImageData(from: imageData) ?? imageData
            let tex = try loader.newTexture(data: textureData, options: options)
            Task { @MainActor in
                scopeState.texture = tex
            }
        } catch {
            print("Error loading texture: \(error)")
        }
    }
    
    public func animateKaleidoscope() {
        guard scopeState.animate else { return }
        let elapsed = CACurrentMediaTime() - scopeState.lastAnimationStepTime
        scopeState.animateByElapsed(elapsed)
    }
    
    func draw(in view: MTKView) {
        let width = view.drawableSize.width
        let height = view.drawableSize.height
        guard height != 0 else {
            print("Window height is zero!")
            return
        }
        
#if os(macOS)
        scale = Float(mtkView?.window?.screen?.backingScaleFactor ?? 1.0)
#else
        scale = Float(mtkView?.contentScaleFactor ?? 1)
#endif
        
        if scopeState.animate {
            if ScopeRenderer.logPoints {
                print("Before animate.")
                print("   trianglePoints.point1 = \(scopeState.trianglePoints.point1.myDescription)")
                print("   trianglePoints.point2 = \(scopeState.trianglePoints.point2.myDescription)")
                print("   trianglePoints.point3 = \(scopeState.trianglePoints.point3.myDescription)")
            }
            animateKaleidoscope()
            if ScopeRenderer.logPoints {
                print("After animate.")
                print("   trianglePoints.point1 = \(scopeState.trianglePoints.point1.myDescription)")
                print("   trianglePoints.point2 = \(scopeState.trianglePoints.point2.myDescription)")
                print("   trianglePoints.point3 = \(scopeState.trianglePoints.point3.myDescription)")
            }
        }
        
        guard let drawable = view.currentDrawable else {
            print("[ScopeRenderer] currentDrawable is nil")
            return
        }
        guard let descriptor = view.currentRenderPassDescriptor else {
            print("[ScopeRenderer] currentRenderPassDescriptor is nil")
            return
        }
        guard let pipeline = pipeline else {
            print("[ScopeRenderer] pipeline is nil")
            return
        }
        guard scopeState.texture != nil else { return }
        
        let colorComponents = scopeState.backgroundColor.components()
        descriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: colorComponents[0],
            green: colorComponents[1],
            blue: colorComponents[2],
            alpha: colorComponents[3])
        descriptor.colorAttachments[0].loadAction = .clear
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(scopeState.texture, index: 0)
        
        renderToEncoder(encoder: encoder, drawableWidth: width, drawableHeight: height, skipOverlays: false)
        
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
        scopeState.lastAnimationStepTime = CACurrentMediaTime()
    }
    
    /// Core rendering logic shared by on-screen draw(in:) and off-screen export.
    /// Draws all kaleidoscope elements to the given encoder.
    /// When `skipOverlays` is true, crop rect overlays are omitted (for image/video export). (outlines are drawn if requested)
    /// When `exportCropRect` is provided, the ortho matrix is computed from the crop rect bounds
    /// so that only the region within the crop rect fills the output.
    func renderToEncoder(
        encoder: MTLRenderCommandEncoder,
        drawableWidth: Double,
        drawableHeight: Double,
        skipOverlays: Bool,
        exportCropRect: MetalRect? = nil
    ) {
        guard let texture = scopeState.texture else { return }
        
        let aspect = Float(drawableWidth / drawableHeight)
        let texWidth = Float(texture.width)
        let texHeight = Float(texture.height)
        let texAspect = texWidth / texHeight
        
        var orthoMatrix = matrix_identity_float4x4
        if let cropRect = exportCropRect {
            // Map the crop rect bounds to fill the entire output texture
            orthoMatrix.columns.0.x = 1.0 / cropRect.topRight.x
            orthoMatrix.columns.1.y = 1.0 / cropRect.topRight.y
        } else {
            orthoMatrix.columns.0.x = 1.0 / aspect
        }
        
        let outerThickness: Float = 6.0
        let innerThickness: Float = 2.0
        
        let template: ScopeTemplate = ScopeWorks2App.scopeTemplates[scopeState.selectedScopeType]
        
        if template.isCircular {
            let multiplier: Float = scopeState.selectedScopeType == 1 ? Float(scopeState.zoom) : Float(scopeState.zoom) / 2.0
            for (_, anElement) in template.elements.enumerated() {
                var center = simd_float2(anElement.center)
                center.x *= multiplier
                center.y *= multiplier
                var radius: Float = Float(anElement.radius) * multiplier
                if scopeState.selectedScopeType == 1 {
                    radius *= scopeState.radiusScale
                }
                for i in 0..<scopeState.polygonSides {
                    let angle = fmod((Float(i) *  2  * (.pi / Float(scopeState.polygonSides)) + anElement.startAngle), Float.pi * 2)
                    let cosA = cos(angle)
                    let sinA = sin(angle)
                    let nextA = fmod((Float(i+1) * 2 *  (.pi / Float(scopeState.polygonSides)) + anElement.startAngle), Float.pi * 2)
                    let cosB = cos(nextA)
                    let sinB = sin(nextA)
                    let point2x = (radius * cosA + center.x)
                    let point3x = (radius * cosB + center.x)
                    let point2y = (radius * sinA + center.y)
                    let point3y = (radius * sinB + center.y)
                    let point2: simd_float2 = simd_float2(point2x, point2y)
                    let point3: simd_float2 = simd_float2(point3x, point3y)
                    
                    var verts: [simd_float2]
                    if scopeState.flipAlternates && !i.isMultiple(of: 2)  {
                        verts = [center, point3, point2]
                    } else {
                        verts = [center, point2, point3]
                    }
                    
                    encoder.setVertexBytes(verts, length: MemoryLayout<simd_float2>.stride * 3, index: 0)
                    
                    var uniforms: Uniforms = Uniforms(
                        color: simd_float4(1, 1, 1, 1),
                        drawWithTetxure: true,
                        drawTextureTriangles: true,
                        textureTriangle: scopeState.trianglePoints,
                        texAspect: texAspect,
                        orthoMatrix: orthoMatrix,
                        flipTextureY: scopeState.flipTextureY
                    )
                    
                    encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
                    encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
                    
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                    
                    if scopeState.drawWithReflection {
                        if scopeState.flipAlternates && !i.isMultiple(of: 2)  {
                            verts = [
                                center,
                                simd_float2(point2x, point2y),
                                simd_float2(point3x, point3y)
                            ]
                        } else {
                            verts = [
                                center,
                                simd_float2(point3x, point3y),
                                simd_float2(point2x, point2y)
                            ]
                        }
                        encoder.setVertexBytes(verts, length: MemoryLayout<simd_float2>.stride * 3, index: 0)
                        
                        var uniforms: Uniforms = Uniforms(
                            color: simd_float4(1, 1, 1, 1),
                            drawWithTetxure: true,
                            drawTextureTriangles: true,
                            textureTriangle: scopeState.trianglePoints,
                            texAspect: texAspect,
                            orthoMatrix: orthoMatrix,
                            flipTextureY: scopeState.flipTextureY
                        )
                        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
                        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
                        
                        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                    }
                    
                    if scopeState.showOutlines {
                        drawThickLine(encoder: encoder,
                                      p1: verts[1], p2: verts[2],
                                      color: black,
                                      thickness: outerThickness / Float(drawableWidth),
                                      orthoMatrix: orthoMatrix,
                                      texAspect: texAspect)
                        drawThickLine(encoder: encoder,
                                      p1: verts[0], p2: verts[1],
                                      color: black,
                                      thickness: outerThickness / Float(drawableWidth),
                                      orthoMatrix: orthoMatrix,
                                      texAspect: texAspect)
                        drawThickLine(encoder: encoder,
                                      p1: verts[0], p2: verts[2],
                                      color: black,
                                      thickness: outerThickness / Float(drawableWidth),
                                      orthoMatrix: orthoMatrix,
                                      texAspect: texAspect)
                        
                        drawThickLine(encoder: encoder,
                                      p1: verts[1], p2: verts[2],
                                      color: white,
                                      thickness: innerThickness / Float(drawableWidth),
                                      orthoMatrix: orthoMatrix,
                                      texAspect: texAspect)
                        drawThickLine(encoder: encoder,
                                      p1: verts[0], p2: verts[1],
                                      color: white,
                                      thickness: innerThickness / Float(drawableWidth),
                                      orthoMatrix: orthoMatrix,
                                      texAspect: texAspect)
                        drawThickLine(encoder: encoder,
                                      p1: verts[0], p2: verts[2],
                                      color: white,
                                      thickness: innerThickness / Float(drawableWidth),
                                      orthoMatrix: orthoMatrix,
                                      texAspect: texAspect)
                    }
                    // Only draw the crop rect if the user requested it, skipOverLays = false,
                    // and this is the main document scope view.
                    // (skipOverlays is true in off-screen rendering)
                    if scopeState.showCropRect && !skipOverlays && isMainDocumentScopeView {
                        let cropRect = scopeState.selectedAspectRatio.cropRect
                        let colorsAndThicknesses: [(simd_float4, Float)] = [
                            (blue, 6),
                            (red, 4)]
                        let cropMultiplier: Float
                        if !scopeState.selectedAspectRatio.isCropForTiling {
                            cropMultiplier = 1
                        } else if scopeState.selectedScopeType == 1 {
                            cropMultiplier = Float(scopeState.zoom)
                        } else {
                            cropMultiplier = Float(scopeState.zoom) / 2.0
                        }
                        
                        let adjustedCropRect = MetalRect(topLeft: cropRect.topLeft * cropMultiplier, topRight: cropRect.topRight * cropMultiplier, bottomLeft: cropRect.bottomLeft * cropMultiplier, bottomRight: cropRect.bottomRight * cropMultiplier)
                        for (color, thickness) in colorsAndThicknesses {
                            drawThickLine(encoder: encoder,
                                          p1: adjustedCropRect.topLeft, p2: adjustedCropRect.topRight,
                                          color: color,
                                          thickness: 4 / Float(drawableWidth),
                                          orthoMatrix: orthoMatrix,
                                          texAspect: texAspect)
                            drawThickLine(encoder: encoder,
                                          p1: adjustedCropRect.topRight, p2: adjustedCropRect.bottomRight,
                                          color: color,
                                          thickness: thickness / Float(drawableWidth),
                                          orthoMatrix: orthoMatrix,
                                          texAspect: texAspect)
                            drawThickLine(encoder: encoder,
                                          p1: adjustedCropRect.bottomRight, p2: adjustedCropRect.bottomLeft,
                                          color: color,
                                          thickness: thickness / Float(drawableWidth),
                                          orthoMatrix: orthoMatrix,
                                          texAspect: texAspect)
                            drawThickLine(encoder: encoder,
                                          p1: adjustedCropRect.bottomLeft, p2: adjustedCropRect.topLeft,
                                          color: color,
                                          thickness: thickness / Float(drawableWidth),
                                          orthoMatrix: orthoMatrix,
                                          texAspect: texAspect)
                        }
                    }
                }
            }
        } else {
            // MARK: - 8-way
            // Other non-circular kaleidoscope types (currently 8-way square and 8-way tiles
            
            var uniforms: Uniforms
            

            for (_, anElement) in template.elements.enumerated() {
                uniforms = Uniforms(
                    color: simd_float4(1, 1, 1, 1),
                    drawWithTetxure: true,
                    drawTextureTriangles: true,
                    textureTriangle: scopeState.trianglePoints,
                    texAspect: texAspect,
                    orthoMatrix: orthoMatrix,
                    flipTextureY: scopeState.flipTextureY
                )
                encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
                encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)


                guard anElement.type == .eightWay else { continue }
                let center = simd_float2(anElement.center)
                let radius: Float = Float(anElement.radius)
                let topLeft = center + simd_float2(-radius, radius)
                let topRight = center + simd_float2(radius, radius)
                let bottomLeft = center + simd_float2(-radius, -radius)
                let bottomRight = center + simd_float2(radius, -radius)
                let topMiddle = center + simd_float2(0, radius)
                let middleLeft = center + simd_float2(-radius, 0)
                let middleRight = center + simd_float2(radius, 0)
                let bottomMiddle = center + simd_float2(0, -radius)
                
                //Build the 8 right triangles for this 8-way square
                let triangles: [TrianglePoints] = [
                    TrianglePoints(point1: center, point2: topMiddle, point3: topRight), // T1
                    TrianglePoints(point1: center, point2: middleRight, point3: topRight), // T2
                    TrianglePoints(point1: center, point2: middleRight, point3: bottomRight), // T3
                    TrianglePoints(point1: center, point2: bottomMiddle, point3: bottomRight), // T4
                    TrianglePoints(point1: center, point2: bottomMiddle, point3: bottomLeft), // T5
                    TrianglePoints(point1: center, point2: middleLeft, point3: bottomLeft), // T6
                    TrianglePoints(point1: center, point2: middleLeft, point3: topLeft), // T7
                    TrianglePoints(point1: center, point2: topMiddle, point3: topLeft), // T8
                ]
                // Build the vertex array from the triangles
                var verts: [simd_float2] = []
                for aTriangle in triangles {
                    verts += [aTriangle.point1, aTriangle.point2, aTriangle.point3]
                }
                encoder.setVertexBytes(verts, length: MemoryLayout<simd_float2>.stride * verts.count, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: verts.count)
                
                if scopeState.drawWithReflection {
                    verts = []
                    for aTriangle in triangles {
                        verts.append(aTriangle.point3)
                        verts.append(aTriangle.point2)
                        verts.append(aTriangle.point1)
                    }
                    encoder.setVertexBytes(verts, length: MemoryLayout<simd_float2>.stride * verts.count, index: 0)
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: verts.count)
                }
                
                if scopeState.showOutlines {
                    for aTriangle in triangles {
                        
                        //Draw a thick black outline of each triangle
                        drawThickLine(encoder: encoder,
                                      p1: aTriangle.point1, p2: aTriangle.point2,
                                      color: black,
                                      thickness: outerThickness / Float(drawableWidth),
                                      orthoMatrix: orthoMatrix,
                                      texAspect: texAspect)
                        drawThickLine(encoder: encoder,
                                      p1: aTriangle.point2, p2: aTriangle.point3,
                                      color: black,
                                      thickness: outerThickness / Float(drawableWidth),
                                      orthoMatrix: orthoMatrix,
                                      texAspect: texAspect)
                        drawThickLine(encoder: encoder,
                                      p1: aTriangle.point3, p2: aTriangle.point1,
                                      color: black,
                                      thickness: outerThickness / Float(drawableWidth),
                                      orthoMatrix: orthoMatrix,
                                      texAspect: texAspect)

                        // Now draw a thinner white outline of each triangle
                        drawThickLine(encoder: encoder,
                                      p1: aTriangle.point1, p2: aTriangle.point2,
                                      color: white,
                                      thickness: innerThickness / Float(drawableWidth),
                                      orthoMatrix: orthoMatrix,
                                      texAspect: texAspect)
                        drawThickLine(encoder: encoder,
                                      p1: aTriangle.point2, p2: aTriangle.point3,
                                      color: white,
                                      thickness: innerThickness / Float(drawableWidth),
                                      orthoMatrix: orthoMatrix,
                                      texAspect: texAspect)
                        drawThickLine(encoder: encoder,
                                      p1: aTriangle.point3, p2: aTriangle.point1,
                                      color: white,
                                      thickness: innerThickness / Float(drawableWidth),
                                      orthoMatrix: orthoMatrix,
                                      texAspect: texAspect)
                    }
                }
            }
        }
    }

    // MARK: - Off-screen rendering

    struct OffscreenRenderTarget {
        let msaaTexture: MTLTexture
        let resolveTexture: MTLTexture
        let width: Int
        let height: Int
    }

    func makeOffscreenRenderTarget(width: Int, height: Int) -> OffscreenRenderTarget? {
        guard let device = device else { return nil }

        if sampleCount > 1 {
            let msDesc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            msDesc.textureType = .type2DMultisample
            msDesc.sampleCount = sampleCount
            msDesc.usage = [.renderTarget]
            msDesc.storageMode = .private
            guard let msTex = device.makeTexture(descriptor: msDesc) else { return nil }

            let resolveDesc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            resolveDesc.usage = [.renderTarget, .shaderRead]
            #if os(macOS)
            resolveDesc.storageMode = .managed
            #else
            resolveDesc.storageMode = .shared
            #endif
            guard let resolveTex = device.makeTexture(descriptor: resolveDesc) else { return nil }

            return OffscreenRenderTarget(msaaTexture: msTex, resolveTexture: resolveTex,
                                         width: width, height: height)
        } else {
            let desc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            desc.usage = [.renderTarget, .shaderRead]
            #if os(macOS)
            desc.storageMode = .managed
            #else
            desc.storageMode = .shared
            #endif
            guard let tex = device.makeTexture(descriptor: desc) else { return nil }
            return OffscreenRenderTarget(msaaTexture: tex, resolveTexture: tex,
                                         width: width, height: height)
        }
    }

    /// Computes the adjusted crop rect in model space for the given aspect ratio,
    /// applying the zoom multiplier for tiling crops.
    func adjustedCropRect(for aspectRatio: AspectRatio) -> MetalRect {
        let cropRect = aspectRatio.cropRect
        let cropMultiplier: Float
        if !aspectRatio.isCropForTiling {
            cropMultiplier = 1
        } else if scopeState.selectedScopeType == 1 {
            cropMultiplier = Float(scopeState.zoom)
        } else {
            cropMultiplier = Float(scopeState.zoom) / 2.0
        }
        return MetalRect(
            topLeft: cropRect.topLeft * cropMultiplier,
            topRight: cropRect.topRight * cropMultiplier,
            bottomLeft: cropRect.bottomLeft * cropMultiplier,
            bottomRight: cropRect.bottomRight * cropMultiplier
        )
    }

    /// Render the current kaleidoscope state off-screen at the specified resolution and return a CGImage.
    /// The `aspectRatio` determines which portion of the kaleidoscope to capture (its cropRect).
    func renderOffscreenImage(width: Int, height: Int, aspectRatio: AspectRatio) -> CGImage? {
        guard let target = makeOffscreenRenderTarget(width: width, height: height),
              let pipeline = pipeline,
              let sourceTexture = scopeState.texture else { return nil }

        let descriptor = MTLRenderPassDescriptor()
        if sampleCount > 1 {
            descriptor.colorAttachments[0].texture = target.msaaTexture
            descriptor.colorAttachments[0].resolveTexture = target.resolveTexture
            descriptor.colorAttachments[0].storeAction = .multisampleResolve
        } else {
            descriptor.colorAttachments[0].texture = target.resolveTexture
            descriptor.colorAttachments[0].storeAction = .store
        }

        let colorComponents = scopeState.backgroundColor.components()
        descriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: colorComponents[0], green: colorComponents[1],
            blue: colorComponents[2], alpha: colorComponents[3])
        descriptor.colorAttachments[0].loadAction = .clear

        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(sourceTexture, index: 0)

        let exportCrop = adjustedCropRect(for: aspectRatio)
        renderToEncoder(encoder: encoder,
                        drawableWidth: Double(width),
                        drawableHeight: Double(height),
                        skipOverlays: true,
                        exportCropRect: exportCrop)

        encoder.endEncoding()

        #if os(macOS)
        if let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
            blitEncoder.synchronize(resource: target.resolveTexture)
            blitEncoder.endEncoding()
        }
        #endif

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let ciContext = CIContext()
        guard let ciImage = CIImage(mtlTexture: target.resolveTexture, options: [
            .colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
        ]) else { return nil }

        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        return ciContext.createCGImage(ciImage, from: ciImage.extent,
                                       format: .RGBA8, colorSpace: sRGB)
    }

    /// Render the current kaleidoscope state off-screen into a CVPixelBuffer (for video recording).
    /// Uses a pre-allocated render target to avoid per-frame allocation.
    /// The `aspectRatio` determines which portion of the kaleidoscope to capture.
    func renderOffscreenToPixelBuffer(
        pixelBuffer: CVPixelBuffer,
        renderTarget: OffscreenRenderTarget,
        aspectRatio: AspectRatio
    ) -> Bool {
        guard let pipeline = pipeline,
              let sourceTexture = scopeState.texture else { return false }

        let width = renderTarget.width
        let height = renderTarget.height

        let descriptor = MTLRenderPassDescriptor()
        if sampleCount > 1 {
            descriptor.colorAttachments[0].texture = renderTarget.msaaTexture
            descriptor.colorAttachments[0].resolveTexture = renderTarget.resolveTexture
            descriptor.colorAttachments[0].storeAction = .multisampleResolve
        } else {
            descriptor.colorAttachments[0].texture = renderTarget.resolveTexture
            descriptor.colorAttachments[0].storeAction = .store
        }

        let colorComponents = scopeState.backgroundColor.components()
        descriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: colorComponents[0], green: colorComponents[1],
            blue: colorComponents[2], alpha: colorComponents[3])
        descriptor.colorAttachments[0].loadAction = .clear

        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(sourceTexture, index: 0)

        let exportCrop = adjustedCropRect(for: aspectRatio)
        renderToEncoder(encoder: encoder,
                        drawableWidth: Double(width),
                        drawableHeight: Double(height),
                        skipOverlays: true,
                        exportCropRect: exportCrop)

        encoder.endEncoding()

        #if os(macOS)
        if let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
            blitEncoder.synchronize(resource: renderTarget.resolveTexture)
            blitEncoder.endEncoding()
        }
        #endif

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return false }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        renderTarget.resolveTexture.getBytes(
            baseAddress,
            bytesPerRow: bytesPerRow,
            from: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                           size: MTLSize(width: width, height: height, depth: 1)),
            mipmapLevel: 0
        )

        return true
    }

//    func drawLine(encoder: MTLRenderCommandEncoder,
//                  p1: simd_float2, p2: simd_float2,
//                  color: SIMD4<Float>,
//                  orthoMatrix: float4x4) {
//        let vertices: [SIMD2<Float>] = [p1, p2]
//        encoder.setVertexBytes(vertices, length: MemoryLayout<simd_float2>.stride * 2, index: 0)
//        let trianglePoints = TrianglePoints(point1: zeroPoint, point2: zeroPoint, point3: zeroPoint)
//
//        var uniforms: Uniforms = Uniforms(
//            color: color,
//            drawWithTetxure: false,
//            textureTriangle: trianglePoints,
//            texAspect: texAspect,
//            orthoMatrix: orthoMatrix)
//        )
//        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
//        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
//        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: 2)
//    }

    func drawThickLine(encoder: MTLRenderCommandEncoder,
                       p1: simd_float2, p2: simd_float2,
                       color: SIMD4<Float>,
                       thickness: Float,
                       orthoMatrix: float4x4,
                       texAspect: Float) {
        let thickness = thickness * scale
        let dir = normalize(p2 - p1)

        let normal = simd_float2(-dir.y, dir.x) * thickness / 2
        let v0 = p1 + normal
        let v1 = p1 - normal
        let v2 = p2 + normal
        let v3 = p2 - normal
        let vertices = [v0, v1, v2, v3]
        encoder.setVertexBytes(vertices, length: MemoryLayout<simd_float2>.stride * 4, index: 0)
        let trianglePoints = TrianglePoints(point1: zeroPoint, point2: zeroPoint, point3: zeroPoint)

        var uniforms: Uniforms = Uniforms(
            color: color,
            drawWithTetxure: false,
            drawTextureTriangles: false,
            textureTriangle:  trianglePoints,
            texAspect: texAspect,
            orthoMatrix: orthoMatrix,
            flipTextureY: false
        )
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }

    // Store the drawable size
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        drawableSize = size
        // For example, you may want to adjust your projection or drawing to match portrait/landscape changes
    }
}

