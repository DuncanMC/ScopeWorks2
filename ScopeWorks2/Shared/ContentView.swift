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
    
    @Published var radiusScale = 1.0
    @Published var trianglePoints = TrianglePoints(point1: zeroPoint, point2: zeroPoint, point3: zeroPoint)
    @Published var rotationCenter: SIMD2<Float> = [0.5, 0.5] //TODO

    @Published var selectedScopeType: Int = 0

    @Published var showOutlines: Bool = false
    @Published var useBlackBackground: Bool = false
    @Published var flipAlternates: Bool = true
    @Published var drawWithReflection: Bool = true
    @Published var animate: Bool = false
    @Published var polygonSides = 6
    @Published var rotationSpeed: CGFloat = 10.0 // In degrees per second
    @Published var movementSpeed: CGFloat = 0 // In screen units per second.
    @Published var lastAnimationStepTime: CFTimeInterval = CACurrentMediaTime()

}

class ScopeViewModel: ObservableObject {
    var scopeState: ScopeState
    init(scopeState: ScopeState) {
        self.scopeState = scopeState
//        let scopeTemplates = ScopeWorks2App.scopeTemplates
//        for aTemplate in scopeTemplates {
//            print(aTemplate)
//        }
    }
    
    func changeAnimationState() {
        if scopeState.animate {
            scopeState.lastAnimationStepTime = CACurrentMediaTime()
        }
    }
}

struct ContentView: View {
    
    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 0
        formatter.numberStyle = .none
        formatter.paddingCharacter = " "
        formatter.paddingPosition = .afterPrefix
        formatter.minimum = 4
        formatter.maximum = 100
        return formatter
    }()
    
    @FocusState private var isFocused
    @State private var selection: TextSelection?
    @State private var site = ""


    @State var polygonSidesString = ""
    
    @StateObject var scopeState = ScopeState()
    @StateObject var scopeViewModel = ScopeViewModel(scopeState: ScopeState())
    
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
            ScopeViewRepresentable(scopeState: scopeState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1.0, contentMode: .fit)
                .background(Color.white)
            Spacer()
            ScrollView(.horizontal) {
                VStack(spacing: 10) {
                    HStack(alignment: .center, spacing: 20) {
                        Spacer()
    #if os(iOS)
                        PhotoPickerView(scopeState: scopeState)
    #endif
                        
                        ScopeTypePicker(title: "Kaledioscope Type:", options: ScopeWorks2App.scopeTemplateNamesAndIndexes, selection: $scopeState.selectedScopeType )
                            .frame(width: 360)

                            .onChange(of: scopeState.selectedScopeType) { oldValue, newValue in
//                                print("selectedScopeType = \(newValue)")
                            }
                        
                        
                        LabeledContent(content: {
                            TextField("",
                                      text: $polygonSidesString,
                                      onEditingChanged: { isEditing in
//                                print("In onEditingChanged isEditing = \(isEditing), $polygonSidesString = \(polygonSidesString)")
                            },
                                      onCommit: {
//                                print("In onCommit, $polygonSidesString = \(polygonSidesString)")
                                guard let value = Self.numberFormatter.number(from: polygonSidesString) else {
                                    Task { @MainActor in
                                        self.polygonSidesString = "\(scopeState.polygonSides)"
                                    }
                                    return
                                }
                                scopeState.polygonSides = value.intValue
                                isFocused = false
                            }
                            )
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 30, maxWidth: 50)
                            .focused($isFocused)
                            .onChange(of: isFocused) {
                                if isFocused {
    #if os(iOS)
                                    Task { @MainActor in
                                        UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
                                    }
    #elseif os(macOS)
                                    Task { @MainActor in
                                        NSApplication.shared.tryToPerform(#selector(NSResponder.selectAll(_:)), with: nil)
                                    }
    #endif
                                    selection = .init(range: site.startIndex..<site.endIndex)
                                }
                            }
                            .onAppear() {
                                polygonSidesString = "\(scopeState.polygonSides)"
                            }
                        },
                                       label: {
                            Text("Polygon sides")
                            
                        })
                        .padding()
                        
                        Toggle(isOn: $scopeState.showOutlines) {
                            Text("Show outlines")
                                .frame(maxWidth: .infinity, alignment: toggleAlignment)
                        }
                        Toggle(isOn: $scopeState.useBlackBackground) {
                            Text("Use black background")
                                .frame(maxWidth: .infinity, alignment: toggleAlignment)
                        }
                        Spacer()

                    }
                HStack(alignment: .center,spacing: 20) {
                    Spacer()

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
                    .onChange(of: scopeState.animate) { oldValue, newValue in
                        scopeViewModel.changeAnimationState()
                    }
                    Button("Reverse animation") {
                        scopeState.rotationSpeed *= -1
                        scopeState.movementSpeed *= -1
                    }
                    Spacer()
                }
            }
            }
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
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

