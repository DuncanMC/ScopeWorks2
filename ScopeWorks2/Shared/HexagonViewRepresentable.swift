import SwiftUI
import MetalKit
#if os(macOS)
struct ScopeViewRepresentable: NSViewRepresentable {
    typealias ViewType = MTKView

    @StateObject var scopeState: ScopeState

    
    func makeCoordinator() -> ScopeRenderer {
        ScopeRenderer(scopeState: scopeState)
    }

    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
//        mtkView.isOpaque = true
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.colorPixelFormat = .bgra8Unorm
        context.coordinator.mtkView = mtkView
        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
//        print("In \(#function), showOutlines = \(scopeState.showOutlines)")
        if let imageData = scopeState.selectedImageData {
            context.coordinator.updateImageData(imageData)

        }
    }
}
        
#elseif os(iOS) || os(iPadOS)
struct ScopeViewRepresentable: UIViewRepresentable {
    

    typealias ViewType = MTKView

    @StateObject var scopeState: ScopeState


    func makeCoordinator() -> ScopeRenderer {
        ScopeRenderer(scopeState: scopeState)
    }

    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.isOpaque = true
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

#endif

#if os(iOS)
extension ScopeViewRepresentable {
    func makeUIView(context: Context) -> MTKView { makeNSView(context: context) }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        if let imageData = scopeState.selectedImageData {
            context.coordinator.updateImageData(imageData)

        }
    }
}
#endif
