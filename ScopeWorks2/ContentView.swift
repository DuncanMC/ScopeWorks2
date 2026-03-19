import SwiftUI
import MetalKit
import Combine
/*
#if os(macOS)
    struct KaleidoscopeView: NSViewRepresentable { // use UIViewRepresentable on iOS
#elseif os(iOS) || os(iPadOS)
    struct KaleidoscopeView: UIViewRepresentable { // use UIViewRepresentable on iOS
#endif
 */
#if os(macOS)

struct KaleidoscopeView: NSViewRepresentable { // use UIViewRepresentable on iOS
    
    let imageURL: URL
    @Binding var rotation: Float
    @Binding var segments: Float
    
    func makeCoordinator() -> Renderer {
        Renderer(imageURL: imageURL)
    }
    
    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.colorPixelFormat = .bgra8Unorm
        view.delegate = context.coordinator
        context.coordinator.mtkView = view
        return view
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.rotation = rotation
        context.coordinator.segments = segments
    }
}
#elseif os(iOS) || os(iPadOS)
struct KaleidoscopeView: UIViewRepresentable { // use UIViewRepresentable on iOS

    let imageURL: URL
    @Binding var rotation: Float
    @Binding var segments: Float
    
    func makeCoordinator() -> Renderer {
        Renderer(imageURL: imageURL)
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.colorPixelFormat = .bgra8Unorm
        view.delegate = context.coordinator
        context.coordinator.mtkView = view
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.rotation = rotation
        context.coordinator.segments = segments
    }
}
#elseif os(iOS) || os(iPadOS)
#endif

struct ContentView: View {
    @State private var rotation: Float = 0
    @State private var segments: Float = 6
    @State private var isAnimating = false

    var body: some View {
        VStack {
            KaleidoscopeView(
                imageURL: Bundle.main.url(forResource: "example", withExtension: "png")!,
                rotation: $rotation,
                segments: $segments
            )
            .frame(width: 400, height: 400)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Rotation")
                    Slider(value: $rotation, in: 0...(Float.pi * 2))
                }
                HStack {
                    Text("Segments: \(Int(segments))")
                    Slider(value: $segments, in: 3...12, step: 1)
                }
                Toggle("Play rotation", isOn: $isAnimating)
                    .toggleStyle(.button)
                    .padding(.top, 10)
            }
            .padding()
        }
        .onReceive(Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()) { _ in
            guard isAnimating else { return }
            rotation += 0.01
            if rotation > Float.pi * 2 { rotation -= Float.pi * 2 }
        }
    }
}

