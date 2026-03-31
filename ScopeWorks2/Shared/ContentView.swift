import SwiftUI
import Combine

class ScopeState: ObservableObject {
    @Published var selectedImageData: Data? = nil
    var selectedImageSize: CGSize {
        guard let selectedImageData else { return .zero }
        #if os(iOS)
                guard  let selectedImage: UIImage = UIImage(data: selectedImageData) else {return CGSizeZero}
                return CGSize(width: selectedImage.size.width, height: selectedImage.size.height)
        #elseif os(macOS)
                guard  let selectedImage = NSImage(data: selectedImageData) else {return CGSizeZero}
                return CGSize(width: selectedImage.size.width, height: selectedImage.size.height)
        #endif
    }

    var selectedImageAspectRatio: Float {
        guard selectedImageData != nil,
                selectedImageSize.width > 0 else { return 0 }
        return Float(selectedImageSize.width / selectedImageSize.height)
    }
    
    @Published var trianglePoints = TrianglePoints(point1: zeroPoint, point2: zeroPoint, point3: zeroPoint)
    @Published var rotationCenter: SIMD2<Float> = [0.5, 0.5] //TODO

    @Published var showOutlines: Bool = false
    @Published var useBlackBackground: Bool = false
    @Published var flipAlternates: Bool = true
    @Published var drawWithReflection: Bool = true
    @Published var animate: Bool = false
    @Published var rotationSpeed: CGFloat = 10.0 // In degrees per second
    @Published var movementSpeed: CGFloat = 0 // In screen units per second.
    @Published var lastAnimationStepTime: CFTimeInterval = CACurrentMediaTime()

}

class ScopeManager: ObservableObject {
    var scopeState: ScopeState
    init(scopeState: ScopeState) {
        self.scopeState = scopeState
    }
    
    func changeAnimationState() {
        if scopeState.animate {
            scopeState.lastAnimationStepTime = CACurrentMediaTime()
        }
    }
}

struct ContentView: View {
    
    @StateObject var scopeState = ScopeState()
    @StateObject var scopeManager = ScopeManager(scopeState: ScopeState())
    
    var toggleAlignment: Alignment {
    #if os(macOS)
            return .leading
    #else
            return .trailing
    #endif

    }
    
    #if os(iOS)
        @State private var image: UIImage? = nil
    #elseif os(macOS)
        @State private var image: NSImage? = nil
    #endif
    var body: some View {
        VStack {
            HStack(spacing: 20) {
                Spacer()
                #if os(iOS)
                    PhotoPickerView(scopeState: scopeState)
                        .padding(EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0))
                #endif
                
                Toggle(isOn: $scopeState.showOutlines) {
                    Text("Show outlines")
                                            .frame(maxWidth: .infinity, alignment: toggleAlignment)
                }
                Toggle(isOn: $scopeState.useBlackBackground) {
                    Text("Use black background")
                                            .frame(maxWidth: .infinity, alignment: toggleAlignment)
                }
                Toggle(isOn: $scopeState.flipAlternates) {
                    Text("Flip alternates")
                                            .frame(maxWidth: .infinity, alignment: toggleAlignment)
                }
                Toggle(isOn: $scopeState.drawWithReflection) {
                    Text("Draw with reflection")
                                            .frame(maxWidth: .infinity, alignment: toggleAlignment)
                }
                Toggle(isOn: $scopeState.animate) {
                    Text("Animate")
                                            .frame(maxWidth: .infinity, alignment: toggleAlignment)
                }
                .onChange(of: scopeState.animate) {
                    scopeManager.changeAnimationState()
                }

                Spacer()

            }
//            .padding(EdgeInsets(top: 20, leading: 10, bottom: 0, trailing: 10))
            ScopeViewRepresentable(scopeState: scopeState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1.0, contentMode: .fit)
                .background(Color.white)
                .onChange(of: scopeState.showOutlines) {
                    print("showOutlines = \($scopeState.showOutlines)")
                }
        }
    }
}

#if os(iOS)
import PhotosUI

struct PhotoPickerView: View {
    
    @State private var selectedItem: PhotosPickerItem?
    @StateObject var scopeState: ScopeState
    

    var body: some View {
        PhotosPicker("Select Texture", selection: $selectedItem, matching: .images)
            .onChange(of: selectedItem) { oldValue, newValue in
                Task {
                    if let newValue,
                       let data = try? await newValue.loadTransferable(type: Data.self) {
                        scopeState.selectedImageData = data
                    }
                }
            }
    }
}
#endif

