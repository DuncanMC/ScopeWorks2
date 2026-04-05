import MetalKit
import simd

#if os(iOS)
import UIKit
#endif


extension Float {
    var degreesToRadians: Float {
        return self * .pi / 180
    }
}

public struct TrianglePoints {
    let point1: SIMD2<Float>
    let point2: SIMD2<Float>
    let point3: SIMD2<Float>
}




let black: SIMD4<Float> = SIMD4<Float>(0, 0, 0, 1)
let white: SIMD4<Float> = SIMD4<Float>(1, 1, 1, 1)
let zeroPoint = simd_float2(0,0)

class ScopeRenderer: NSObject, MTKViewDelegate {
    
    static var logPoints: Bool = false
//    static var indexToDraw: Int? = nil
    weak var mtkView: MTKView?
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var pipeline: MTLRenderPipelineState!

    var texture: MTLTexture? {
        didSet {
//            print("In ScopeRenderer texture didSet")
            Task { @MainActor in
                scopeState.trianglePoints = calcTrianglePoints()
                scopeState.rotationCenter = centerPoint(trianglePoints: scopeState.trianglePoints)
            }
        }
    }
    
    var scopeState: ScopeState
    // Track current drawable size for orientation handling
    private(set) var drawableSize: CGSize = .zero
    
    struct Uniforms {
        let color: simd_float4
        let drawWithTetxure: Bool
        let textureTriangle: TrianglePoints
    }
    var imageData: Data?

#if os(iOS)
    init(scopeState: ScopeState) {
        self.scopeState = scopeState
        super.init()
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()
        makePipeline()
        loadTexture()
    }
#elseif os(macOS)
        init(scopeState: ScopeState) {
            self.scopeState = scopeState
            super.init()
            device = MTLCreateSystemDefaultDevice()
            commandQueue = device.makeCommandQueue()
            makePipeline()
            loadTexture()
        }
#endif

    func calcTrianglePoints()
    -> TrianglePoints {
        guard scopeState.selectedImageData != nil else {
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
    

    func makePipeline() {
        let library = device.makeDefaultLibrary()
        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.vertexFunction = library?.makeFunction(name: "vertex_main")
        pipelineDesc.fragmentFunction = library?.makeFunction(name: "fragment_main")
        pipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm

        // ---- New changes
        // Enable blending for transparent drawing
        pipelineDesc.colorAttachments[0].isBlendingEnabled = true
        pipelineDesc.colorAttachments[0].rgbBlendOperation = .add
        pipelineDesc.colorAttachments[0].alphaBlendOperation = .add
        pipelineDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDesc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        // ---- end of new changes
        
        pipeline = try! device.makeRenderPipelineState(descriptor: pipelineDesc)
    }

    func updateImageData(_ imageData: Data?) {
        if imageData != self.imageData {
            self.imageData = imageData
            loadTexture()
        }
    }

    func loadTexture() {
#if os(macOS)
        if let url = Bundle.main.url(forResource: "example", withExtension: "png"),
//        if let url = Bundle.main.url(forResource: "test 2", withExtension: "png"),
           let imageData = try? Data(contentsOf: url) {
            
            Task { @MainActor in
                scopeState.selectedImageData = imageData
            }
            let loader = MTKTextureLoader(device: device)
            do {
                let options: [MTKTextureLoader.Option: Any] =
                [.origin:MTKTextureLoader.Origin.bottomLeft,
                 .generateMipmaps: true]
                texture = try loader.newTexture(data: imageData, options: options)
                if let tex = texture {
                    let hasAlpha =
                    tex.pixelFormat == .rgba8Unorm ||
                    tex.pixelFormat == .rgba8Unorm_srgb ||
                    tex.pixelFormat == .bgra8Unorm ||
                    tex.pixelFormat == .bgra8Unorm_srgb ||
                    tex.pixelFormat == .rgba16Float ||
                    tex.pixelFormat == .rgba32Float
//                    print("[ScopeRenderer] Loaded texture pixel format: \(tex.pixelFormat) | hasAlpha: \(hasAlpha)")
                } else {
                    print("[ScopeRenderer] Failed to load texture.")
                }
            } catch {
                print("Error loading texture: \(error)")
            }
        }
#else
            let loader = MTKTextureLoader(device: device)
//            texture = try loader.newTexture(cgImage: img.cgImage!, options: [MTKTextureLoaderOptionOrigin: MTKTextureLoaderOriginTopLeft as NSObject])
                do {
                    guard let imageData,
                          let image = UIImage(data: imageData)
                    else { return }
                    let options: [MTKTextureLoader.Option: Any] =
                    [.origin:MTKTextureLoader.Origin.bottomLeft,
                     .generateMipmaps: true]
//                    texture = try loader.newTexture(data: imageData, options: options)
                    texture = try loader.newTexture(cgImage: image.cgImage!, options: options)

                    if let tex = texture {
                        let hasAlpha =
                        tex.pixelFormat == .rgba8Unorm ||
                        tex.pixelFormat == .rgba8Unorm_srgb ||
                        tex.pixelFormat == .bgra8Unorm ||
                        tex.pixelFormat == .bgra8Unorm_srgb ||
                        tex.pixelFormat == .rgba16Float ||
                        tex.pixelFormat == .rgba32Float
//                        print("[ScopeRenderer] Loaded texture pixel format: \(tex.pixelFormat) | hasAlpha: \(hasAlpha)")
                    } else {
                        print("[ScopeRenderer] Failed to load texture.")
                    }
                } catch {
                    print("Error loading texture: \(error)")
                }
#endif
    }

    public func animateKaleidoscope() {
        let elapsed = CACurrentMediaTime() - scopeState.lastAnimationStepTime
        let degrees = Float(elapsed * Double(scopeState.rotationSpeed))
        let radians = degrees.degreesToRadians
        scopeState.trianglePoints = rotateTriangle(trianglePoints: scopeState.trianglePoints, angle: radians, aroundCenter: scopeState.rotationCenter)
    }
    
    func draw(in view: MTKView) {
        
        let outerThickness: Float = 6.0
        let innerThickness: Float = 2.0
        let blackValues = [0.0, 0.0, 0.0, 1.0]
        let whiteValues = [1.0, 1.0, 1.0, 1.0]
        
        
        if scopeState.animate {
            animateKaleidoscope()
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
        guard let texture = texture else {
//            print("[ScopeRenderer] texture is nil")
            return
        }

        let commandBuffer = commandQueue.makeCommandBuffer()!
        if scopeState.useBlackBackground {
            descriptor.colorAttachments[0].clearColor = MTLClearColor(
                red: blackValues[0],
                green: blackValues[1],
                blue: blackValues[2],
                alpha: blackValues[3])
        } else {
            descriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: whiteValues[0],
            green: whiteValues[1],
            blue: whiteValues[2],
            alpha: whiteValues[3])
        }
        descriptor.colorAttachments[0].loadAction =  MTLLoadAction.clear
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        
        let template: ScopeTemplate = ScopeWorks2App.scopeTemplates[scopeState.selectedScopeType]
        if template.isCircular {
            for (_, anElement) in template.elements.enumerated() {
                let center = simd_float2(anElement.center)
                let radius: Float = Float(anElement.radius * scopeState.radiusScale)
                for i in 0..<scopeState.polygonSides {
//                    print("Center = \(center.myDescription)")
                    let angle = fmod((Float(i) *  2  * (.pi / Float(scopeState.polygonSides)) + anElement.startAngle), Float.pi * 2)
                    let cosA = cos(angle)
                    let sinA = sin(angle)
                    let nextA = fmod((Float(i+1) * 2 *  (.pi / Float(scopeState.polygonSides)) + anElement.startAngle), Float.pi * 2)
                    let cosB = cos(nextA)
                    let sinB = sin(nextA)
                    // Zoom in
                    let point2x = radius * cosA + center.x
                    let point3x = radius * cosB + center.x
                    let point2y = radius * sinA + center.y
                    let point3y = radius * sinB + center.y
                    let point2: simd_float2 = simd_float2(point2x, point2y)
                    let point3: simd_float2 = simd_float2(point3x, point3y)
                    
                    var verts: [simd_float2]
                    if i.isMultiple(of: 2) && scopeState.flipAlternates {
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
                    
                    if ScopeRenderer.logPoints {
                        print("point2 = \(point2.myDescription)")
                        print("point3 = \(point3.myDescription)")
                    }
                    encoder.setVertexBytes(verts, length: MemoryLayout<simd_float2>.stride * 3, index: 0)
                    
                    var uniforms: Uniforms = Uniforms(
                        color: simd_float4(1, 1, 1, 1),
                        drawWithTetxure: true,
                        textureTriangle: scopeState.trianglePoints
                    )
                    
                    encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
                    encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
                    
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

                    if scopeState.drawWithReflection {
                        if i.isMultiple(of: 2) && scopeState.flipAlternates {
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
                                textureTriangle: scopeState.trianglePoints
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
                                      thickness:  outerThickness / Float(drawableSize.width))
                        drawThickLine(encoder: encoder,
                                      p1: verts[0], p2: verts[1],
                                      color: black,
                                      thickness: outerThickness / Float(drawableSize.width))
                        drawThickLine(encoder: encoder,
                                      p1: verts[0], p2: verts[2],
                                      color: black,
                                      thickness: outerThickness / Float(drawableSize.width))
                        
                        drawThickLine(encoder: encoder,
                                      p1: verts[1], p2: verts[2],
                                      color: white,
                                      thickness: innerThickness / Float(drawableSize.width))
                        drawThickLine(encoder: encoder,
                                      p1: verts[0], p2: verts[1],
                                      color: white,
                                      thickness: innerThickness / Float(drawableSize.width))
                        drawThickLine(encoder: encoder,
                                      p1: verts[0], p2: verts[2],
                                      color: white,
                                      thickness: innerThickness / Float(drawableSize.width))
                        
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

    func drawLine(encoder: MTLRenderCommandEncoder,
                  p1: simd_float2, p2: simd_float2,
                  color: SIMD4<Float>) {
        let vertices: [SIMD2<Float>] = [p1, p2]
        encoder.setVertexBytes(vertices, length: MemoryLayout<simd_float2>.stride * 2, index: 0)
        let trianglePoints = TrianglePoints(point1: zeroPoint, point2: zeroPoint, point3: zeroPoint)

        var uniforms: Uniforms = Uniforms(
            color: color,
            drawWithTetxure: false,
            textureTriangle: trianglePoints
        )
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: 2)
    }

    func drawThickLine(encoder: MTLRenderCommandEncoder,
                       p1: simd_float2, p2: simd_float2,
                       color: SIMD4<Float>, thickness: Float) {
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
            textureTriangle:  trianglePoints
        )
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }

    // Store the drawable size
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        drawableSize = size
        // Optionally, update any scale/aspect-ratio logic here
        // For example, you may want to adjust your projection or drawing to match portrait/landscape changes
    }
}

