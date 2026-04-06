import MetalKit
import simd

#if os(iOS)
import UIKit
#endif





class SourceImageRenderer: NSObject, MTKViewDelegate {
    
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
        let drawTextureTriangles: Bool
        let textureTriangle: TrianglePoints
        let texAspect: Float
        let orthoMatrix: float4x4
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

        // Enable blending for transparent drawing
        pipelineDesc.colorAttachments[0].isBlendingEnabled = true
        pipelineDesc.colorAttachments[0].rgbBlendOperation = .add
        pipelineDesc.colorAttachments[0].alphaBlendOperation = .add
        pipelineDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDesc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
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
        if let url = Bundle.main.url(forResource: scopeState.textureName, withExtension: "png"),
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
                    texture = try loader.newTexture(cgImage: image.cgImage!, options: options)

                    if let tex = texture {
                        let hasAlpha =
                        tex.pixelFormat == .rgba8Unorm ||
                        tex.pixelFormat == .rgba8Unorm_srgb ||
                        tex.pixelFormat == .bgra8Unorm ||
                        tex.pixelFormat == .bgra8Unorm_srgb ||
                        tex.pixelFormat == .rgba16Float ||
                        tex.pixelFormat == .rgba32Float
                    } else {
                        print("[ScopeRenderer] Failed to load texture.")
                    }
                } catch {
                    print("Error loading texture: \(error)")
                }
#endif
    }

    
    func draw(in view: MTKView) {
        
        let width = view.drawableSize.width
        let height = view.drawableSize.height
        guard height != 0 else {
            print("Window height is zero!")
            return
        }
        
        let aspect = Float(width / height)
        
        // In your vertex shader, multiply positions by orthoMatrix
        
        let blackValues = [0.0, 0.0, 0.0, 1.0]
        let whiteValues = [1.0, 1.0, 1.0, 1.0]
        
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
        
        let texWidth = Float(texture.width)
        let texHeight = Float(texture.height)
        let texAspect = texWidth / texHeight
        
        // Model-View-Projection matrix example
        var orthoMatrix = matrix_identity_float4x4
        orthoMatrix.columns.0.x = 1.0 / aspect // scale X by 1/aspect
        
        
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
        var factor: Float
        if texAspect >= 1 {
            factor = 1.0
        } else {
            factor = 0.75
        }
        var verts: [simd_float2]
        switch texAspect {
        case 1.0:
            verts = [simd_float2(x: -1, y:  1), // point1
                     simd_float2(x:  1, y: 1 ), // point2
                     simd_float2(x: 1, y: -1)   //point3
            ]
        case let value where value > 1.0:
            verts = [simd_float2(x: -1, y:  1),  // point1
                     simd_float2(x:  1 , y: 1 ),  // point2
                     simd_float2(x: 1 / texAspect, y: -1)    // point3
            ]
        default: // aspect < 1.0
            verts = [simd_float2(x: -1, y:  1),  // point1
                     simd_float2(x:  factor * texAspect, y: 1 ),   // point2
                     simd_float2(x: factor * texAspect, y: -1)    // point3
            ]
        }
        
        encoder.setVertexBytes(verts, length: MemoryLayout<simd_float2>.stride * 3, index: 0)
        
        var uniforms: Uniforms = Uniforms(
            color: simd_float4(1, 1, 1, 1),
            drawWithTetxure: true,
            drawTextureTriangles: false,
            textureTriangle: scopeState.trianglePoints,
            texAspect: 1,
            orthoMatrix: orthoMatrix
            // In your vertex shader, multiply positions by orthoMatrix
        )
        
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        
        switch texAspect {
        case 1.0:
            verts = [simd_float2(x: -1, y:  1), // point1
                     simd_float2(x:  1, y: -1), // point3
                     simd_float2(x:  -1, y: -1) // point4
            ]
        case let value where value > 1.0:
            verts = [simd_float2(x: -1, y:  1), // point1
                     simd_float2(x:  1, y: -1), // point3
                     simd_float2(x:  -1, y: -1) // point4
            ]
        default:
            
            verts = [simd_float2(x: -1, y:  1), // point1
                     simd_float2(x:  factor * texAspect, y: -1), // point3
                     simd_float2(x:  -1, y: -1) // point4
            ]
        }
        
        encoder.setVertexBytes(verts, length: MemoryLayout<simd_float2>.stride * 3, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

        
        
        
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
        scopeState.lastAnimationStepTime = CACurrentMediaTime()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        drawableSize = size
        // For example, you may want to adjust your projection or drawing to match portrait/landscape changes
    }
}

