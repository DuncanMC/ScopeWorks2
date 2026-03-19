import MetalKit
import simd

final class Renderer: NSObject, MTKViewDelegate {
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var pipeline: MTLRenderPipelineState!
    var texture: MTLTexture?
    weak var mtkView: MTKView?
    
    var rotation: Float = 0
    var segments: Float = 6
    
    struct Uniforms {
        var rotation: Float
        var segments: Float
    }

    init(imageURL: URL) {
        super.init()
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()
        setupPipeline()
        loadTexture(from: imageURL)
    }

    func setupPipeline() {
        let library = device.makeDefaultLibrary()
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library?.makeFunction(name: "vertex_main")
        descriptor.fragmentFunction = library?.makeFunction(name: "fragment_kaleidoscope")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipeline = try! device.makeRenderPipelineState(descriptor: descriptor)
    }

    func loadTexture(from url: URL) {
        let loader = MTKTextureLoader(device: device)
        texture = try? loader.newTexture(URL: url, options: [
            .origin: MTKTextureLoader.Origin.flippedVertically
        ])
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let texture = texture else { return }
        
        var uniforms = Uniforms(rotation: rotation, segments: segments)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
