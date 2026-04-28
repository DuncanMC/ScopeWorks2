import MetalKit
import simd
import SwiftUI



#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

/// Redraw an image from Data so the returned image is always in the default ("up") orientation, as PNG data.
func normalizedImageData(from imageData: Data) -> Data? {
#if os(iOS)
    guard let image = UIImage(data: imageData) else { return nil }
    // If already up, nothing to do.
    if image.imageOrientation == .up, let pngData = image.pngData() {
        return pngData
    }
    // Redraw to "up" orientation
    let renderer = UIGraphicsImageRenderer(size: image.size)
    let normalizedImage = renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: image.size))
    }
    return normalizedImage.pngData()
#elseif os(macOS)
    guard let nsImage = NSImage(data: imageData) else { return nil }
    let imageRect = NSRect(origin: .zero, size: nsImage.size)
    guard let rep = nsImage.bestRepresentation(for: imageRect, context: nil, hints: nil) else { return nil }
    let bmp = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(nsImage.size.width), pixelsHigh: Int(nsImage.size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
    guard let bmpRep = bmp else { return nil }
    NSGraphicsContext.saveGraphicsState()
    if let ctx = NSGraphicsContext(bitmapImageRep: bmpRep) {
        NSGraphicsContext.current = ctx
        rep.draw(in: imageRect)
        ctx.flushGraphics()
    }
    NSGraphicsContext.restoreGraphicsState()
    return bmpRep.representation(using: .png, properties: [:])
#else
    return nil
#endif
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
    
    var scale: Float = 1.0

    var sampleCount: Int = 1
    var imageUUID: UUID? = nil
    static var logPoints: Bool = false
//    static var indexToDraw: Int? = nil
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
    }

#if os(iOS)
    init(scopeState: ScopeState) {
        self.scopeState = scopeState
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
#elseif os(macOS)
        init(scopeState: ScopeState) {
            self.scopeState = scopeState
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
        if true {
            if let scopeImageUUID = scopeState.imageUUID,
               imageUUID != scopeImageUUID {
                print("New image, UUID = \(scopeImageUUID), reloading texture")
                loadTexture()
                imageUUID = scopeState.imageUUID
            }
        }
    }

    func loadTexture() {
#if os(macOS)
//        if let url = scopeState.imageURL,
//           let imageData = try? Data(contentsOf: url) {
            
        guard var imageData = scopeState.selectedImageData else { return }
        if scopeState.isHEIC {
            if let normalizedImageData = normalizedImageData(from: imageData) {
                imageData = normalizedImageData
            }

        }
//        Task { @MainActor in
//            scopeState.selectedImageData = imageData
//            imageUUID = scopeState.imageUUID
//        }
        let loader = MTKTextureLoader(device: device)
        do {
            let options: [MTKTextureLoader.Option: Any] = [.origin:MTKTextureLoader.Origin.bottomLeft, .generateMipmaps: true]
            let tex = try loader.newTexture(data: imageData, options: options)
            Task { @MainActor in
                scopeState.texture = tex
            }
            let hasAlpha =
            tex.pixelFormat == .rgba8Unorm ||
            tex.pixelFormat == .rgba8Unorm_srgb ||
            tex.pixelFormat == .bgra8Unorm ||
            tex.pixelFormat == .bgra8Unorm_srgb ||
            tex.pixelFormat == .rgba16Float ||
            tex.pixelFormat == .rgba32Float
            //                    print("[ScopeRenderer] Loaded texture pixel format: \(tex.pixelFormat) | hasAlpha: \(hasAlpha)")
        } catch {
            print("Error loading texture: \(error)")
        }
#else
            let loader = MTKTextureLoader(device: device)
                do {
                    guard var imageData = scopeState.selectedImageData else { return }
                    if scopeState.isHEIC {
                        if let normalizedImageData = normalizedImageData(from: imageData) {
                            imageData = normalizedImageData
                        }
                    }
                    let options: [MTKTextureLoader.Option: Any] =
                    [.origin:MTKTextureLoader.Origin.bottomLeft,
                     .generateMipmaps: true]
                    let tex = try loader.newTexture(data: imageData, options: options)
                    Task { @MainActor in
                        scopeState.texture = tex
                    }

                    let hasAlpha =
                    tex.pixelFormat == .rgba8Unorm ||
                    tex.pixelFormat == .rgba8Unorm_srgb ||
                    tex.pixelFormat == .bgra8Unorm ||
                    tex.pixelFormat == .bgra8Unorm_srgb ||
                    tex.pixelFormat == .rgba16Float ||
                    tex.pixelFormat == .rgba32Float
                } catch {
                    print("Error loading texture: \(error)")
                }
#endif
    }

    public func animateKaleidoscope() {
        guard scopeState.animate else { return }
        let elapsed = CACurrentMediaTime() - scopeState.lastAnimationStepTime
        let degrees = Float(elapsed * Double(scopeState.rotationSpeed))
        let radians = degrees.degreesToRadians
        let changed = rotateTriangle(trianglePoints: scopeState.trianglePoints, angle: radians, aroundCenter: scopeState.rotationCenter)
        let adjustment = scopeState.adjustTrianglePoints(trianglePoints: changed)
        scopeState.trianglePoints = adjustment.points
        if adjustment.adjusted {
            scopeState.rotationCenter = scopeState.rotationCenter.adjustedBy(dx: adjustment.dx ?? 0, dy: adjustment.dy ?? 0)
        }
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

        let aspect = Float(width / height)
        
          // In your vertex shader, multiply positions by orthoMatrix
        
        let outerThickness: Float = 6.0
        let innerThickness: Float = 2.0
        
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

        //print("[ScopeRenderer] draw(in:) called. drawableSize: \(drawableSize), view.bounds: \(view.bounds)")
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
        guard let texture = scopeState.texture else {
//            print("[ScopeRenderer] texture is nil")
            return
        }

        let texWidth = Float(texture.width)
        let texHeight = Float(texture.height)
        let texAspect = texWidth / texHeight
        
        // Model-View-Projection matrix example
          var orthoMatrix = matrix_identity_float4x4
          orthoMatrix.columns.0.x = 1.0 / aspect // scale X by 1/aspect

        let commandBuffer = commandQueue.makeCommandBuffer()!
        let colorComponents = scopeState.backgroundColor.components()
        
        descriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: colorComponents[0],
            green: colorComponents[1],
            blue: colorComponents[2],
            alpha: colorComponents[3])

        descriptor.colorAttachments[0].loadAction =  MTLLoadAction.clear
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        
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
                    // Zoom in
                    let point2x = (radius * cosA + center.x)
                    let point3x = (radius * cosB + center.x)
                    let point2y = (radius * sinA + center.y)
                    let point3y = (radius * sinB + center.y)
                    let point2: simd_float2 = simd_float2(point2x, point2y)
                    let point3: simd_float2 = simd_float2(point3x, point3y)
                    
                    var verts: [simd_float2]
                    if scopeState.flipAlternates && !i.isMultiple(of: 2)  {
                        verts = [
                            center,
                            point3,
                            point2
                        ]
                        
                    } else {
                        verts = [
                            center,
                            point2,
                            point3
                        ]
                        
                    }
                    
//                    if ScopeRenderer.logPoints {
//                        print("point2 = \(point2.myDescription)")
//                        print("point3 = \(point3.myDescription)")
//                    }
                    encoder.setVertexBytes(verts, length: MemoryLayout<simd_float2>.stride * 3, index: 0)
                    
                    var uniforms: Uniforms = Uniforms(
                        color: simd_float4(1, 1, 1, 1),
                        drawWithTetxure: true,
                        drawTextureTriangles: true,
                        textureTriangle: scopeState.trianglePoints,
                        texAspect: texAspect,
                        orthoMatrix: orthoMatrix
                          // In your vertex shader, multiply positions by orthoMatrix
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
                                orthoMatrix: orthoMatrix
                            )
                            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
                            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
                            
                            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                    }
                    
                    if scopeState.showOutlines {
                        // Draw outlines using drawThickLine()
                        drawThickLine(encoder: encoder,
                                      p1: verts[1], p2: verts[2],
                                      color: black,
                                      thickness:  outerThickness / Float(drawableSize.width),
                                      orthoMatrix: orthoMatrix,
                                      texAspect: texAspect)
                        drawThickLine(encoder: encoder,
                                      p1: verts[0], p2: verts[1],
                                      color: black,
                                      thickness: outerThickness / Float(drawableSize.width),
                                      orthoMatrix: orthoMatrix,
                                      texAspect: texAspect)
                        drawThickLine(encoder: encoder,
                                      p1: verts[0], p2: verts[2],
                                      color: black,
                                      thickness: outerThickness / Float(drawableSize.width),
                                      orthoMatrix: orthoMatrix,
                                      texAspect: texAspect)

                        drawThickLine(encoder: encoder,
                                      p1: verts[1], p2: verts[2],
                                      color: white,
                                      thickness: innerThickness / Float(drawableSize.width),
                                      orthoMatrix: orthoMatrix,
                                      texAspect: texAspect)
                        drawThickLine(encoder: encoder,
                                      p1: verts[0], p2: verts[1],
                                      color: white,
                                      thickness: innerThickness / Float(drawableSize.width),
                                      orthoMatrix: orthoMatrix,
                                      texAspect: texAspect)
                        drawThickLine(encoder: encoder,
                                      p1: verts[0], p2: verts[2],
                                      color: white,
                                      thickness: innerThickness / Float(drawableSize.width),
                                      orthoMatrix: orthoMatrix,
                                      texAspect: texAspect)

                        //            //Now draw again with a 1-pixel thick white line
                        //            drawLine(encoder: encoder,
                        //                          p1: verts[1], p2: verts[2],
                        //                          color: white)
                        //            drawLine(encoder: encoder,
                        //                          p1: verts[0], p2: verts[1],
                        //                          color: white)
                        //            drawLine(encoder: encoder,
                        //                          p1: verts[0], p2: verts[2],
                        //                          color: white)
                    }
                }
            }
        } else {
            
        }
        


        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
        scopeState.lastAnimationStepTime = CACurrentMediaTime()
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
            orthoMatrix: orthoMatrix
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

