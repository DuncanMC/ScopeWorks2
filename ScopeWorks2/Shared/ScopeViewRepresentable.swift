import SwiftUI
import MetalKit
#if os(iOS) || os(iPadOS)
    import UIKit
#endif
#if os(macOS)
struct ScopeViewRepresentable: NSViewRepresentable {
    typealias ViewType = MTKView
    
    var allowImageExport: Bool
    var isMainDocumentScopeView: Bool
    weak var metalView: MTKView? = nil
    @ObservedObject var scopeState: ScopeState
    
    init(scopeState: ScopeState, allowImageExport: Bool = false, isMainDocumentScopeView: Bool) {
        self.scopeState = scopeState
        self.allowImageExport = allowImageExport
        self.isMainDocumentScopeView = isMainDocumentScopeView
    }
    
    
    
    func makeCoordinator() -> ScopeRenderer {
        ScopeRenderer(scopeState: scopeState, isMainDocumentScopeView: isMainDocumentScopeView)
    }
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.sampleCount = context.coordinator.sampleCount
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = !allowImageExport
        context.coordinator.mtkView = mtkView
        //xxx
        if allowImageExport {
            if isMainDocumentScopeView {
                scopeState.documentMetalView = mtkView
                scopeState.documentRenderer = context.coordinator
            } else {
                scopeState.fullscreenMetalView = mtkView
                scopeState.fullscreenRenderer = context.coordinator
            }
        }
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // Keep the weak renderer reference current across view updates
        if isMainDocumentScopeView && scopeState.documentRenderer !== context.coordinator {
            scopeState.documentRenderer = context.coordinator
        }
        if scopeState.imageSourceMode == .staticImage && scopeState.selectedImageData != nil {
            context.coordinator.updateImageData()
        }
    }
}
        
#elseif os(iOS) || os(iPadOS)
struct TwoFingerTapGesture: UIGestureRecognizerRepresentable {
    var action: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UITapGestureRecognizer {
        let recognizer = UITapGestureRecognizer()
        recognizer.numberOfTouchesRequired = 2
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UITapGestureRecognizer, context: Context) {
        if recognizer.state == .recognized {
            action()
        }
    }
}

struct ScopeViewRepresentable: UIViewRepresentable {

    typealias ViewType = MTKView

    var isMainDocumentScopeView: Bool
    var allowImageExport: Bool
    weak var metalView: MTKView? = nil

    @ObservedObject var scopeState: ScopeState

    init(scopeState: ScopeState, allowImageExport: Bool = false, isMainDocumentScopeView: Bool) {
        self.scopeState = scopeState
        self.allowImageExport = allowImageExport
        self.isMainDocumentScopeView = isMainDocumentScopeView
    }

    func makeCoordinator() -> ScopeRenderer {
        ScopeRenderer(scopeState: scopeState, isMainDocumentScopeView: isMainDocumentScopeView)
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
        if isMainDocumentScopeView {
            scopeState.documentMetalView = mtkView
            scopeState.documentRenderer = context.coordinator
        } else {
            scopeState.fullscreenMetalView = mtkView
            scopeState.fullscreenRenderer = context.coordinator
        }
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // Keep the weak renderer reference current across view updates
        if isMainDocumentScopeView && scopeState.documentRenderer !== context.coordinator {
            scopeState.documentRenderer = context.coordinator
        }
        if scopeState.imageSourceMode == .staticImage && scopeState.selectedImageData != nil {
            context.coordinator.updateImageData()
        }
    }
}
#endif

