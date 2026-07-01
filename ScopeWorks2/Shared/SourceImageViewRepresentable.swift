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
        mtkView.sampleCount = context.coordinator.sampleCount
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.colorPixelFormat = .bgra8Unorm
        context.coordinator.mtkView = mtkView
        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
//        print("In SourceImageViewRepresentable.updateNSView")
//        if let imageData = scopeState.selectedImageData {
//            context.coordinator.updateImageData(imageData)
//        }
    }
}
        
#elseif os(iOS) || os(iPadOS)
struct SourceImageViewRepresentable: UIViewRepresentable {
    typealias UIViewType = MTKView
    


    @StateObject var scopeState: ScopeState


    func makeCoordinator() -> SourceImageRenderer {
        SourceImageRenderer(scopeState: scopeState)
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.sampleCount = context.coordinator.sampleCount
        mtkView.isOpaque = true
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.colorPixelFormat = .bgra8Unorm
        context.coordinator.mtkView = mtkView
        return mtkView
    }

    func updateUIView(_ nsView: MTKView, context: Context) {

//        if let imageData = scopeState.selectedImageData {
//            context.coordinator.updateImageData()
//
//        }
    }
}

#endif

