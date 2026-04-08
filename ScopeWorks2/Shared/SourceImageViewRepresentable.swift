import SwiftUI
import MetalKit
#if os(macOS)
struct SourceImageViewRepresentable: NSViewRepresentable {
    typealias ViewType = MTKView

    @StateObject var scopeState: ScopeState

    
    func makeCoordinator() -> SourceImageRenderer {
        SourceImageRenderer(scopeState: scopeState)
    }

    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.colorPixelFormat = .bgra8Unorm
        context.coordinator.mtkView = mtkView
        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        if let imageData = scopeState.selectedImageData {
            context.coordinator.updateImageData(imageData)
        }
    }
}
        
#elseif os(iOS) || os(iPadOS)
struct SourceImageViewRepresentable: UIViewRepresentable {
    typealias UIViewType = MTKView
    

    typealias ViewType = MTKView

    @StateObject var scopeState: ScopeState


    func makeCoordinator() -> SourceImageRenderer {
        SourceImageRenderer(scopeState: scopeState)
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.isOpaque = true
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.colorPixelFormat = .bgra8Unorm
        context.coordinator.mtkView = mtkView
        return mtkView
    }

    func updateUIView(_ nsView: MTKView, context: Context) {
        if let imageData = scopeState.selectedImageData {
            context.coordinator.updateImageData(imageData)

        }
    }
}

#endif

