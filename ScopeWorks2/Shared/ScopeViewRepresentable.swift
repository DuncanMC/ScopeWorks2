import SwiftUI
import MetalKit
#if os(macOS)
struct ScopeViewRepresentable: NSViewRepresentable {
    typealias ViewType = MTKView

    var allowImageExport: Bool
    weak var metalView: MTKView? = nil
    @ObservedObject var scopeState: ScopeState

    init (scopeState: ScopeState, allowImageExport: Bool = false) {
        self.scopeState = scopeState
        self.allowImageExport = allowImageExport
    }
    
        
    
    func makeCoordinator() -> ScopeRenderer {
        ScopeRenderer(scopeState: scopeState)
    }

    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.sampleCount = context.coordinator.sampleCount
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = !allowImageExport
        context.coordinator.mtkView = mtkView
        if allowImageExport {
            scopeState.metalView = mtkView
        }
        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        if scopeState.imageSourceMode == .staticImage && scopeState.selectedImageData != nil {
            context.coordinator.updateImageData()
        }
    }
}
        
#elseif os(iOS) || os(iPadOS)
struct ScopeViewRepresentable: UIViewRepresentable {
    

    typealias ViewType = MTKView

    var allowImageExport: Bool
    weak var metalView: MTKView? = nil

    @ObservedObject var scopeState: ScopeState

    init (scopeState: ScopeState, allowImageExport: Bool = false) {
        self.scopeState = scopeState
        self.allowImageExport = allowImageExport
    }

    
    func makeCoordinator() -> ScopeRenderer {
        ScopeRenderer(scopeState: scopeState)
    }
}

extension ScopeViewRepresentable {
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.sampleCount = 4
        
        mtkView.isOpaque = true
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = !allowImageExport
        context.coordinator.mtkView = mtkView
        if allowImageExport {
            scopeState.metalView = mtkView
        }
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        if scopeState.imageSourceMode == .staticImage && scopeState.selectedImageData != nil {
            context.coordinator.updateImageData()
        }
    }
}
#endif

