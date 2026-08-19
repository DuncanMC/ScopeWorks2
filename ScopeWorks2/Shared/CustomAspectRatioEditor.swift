//
//  CustomAspectRatioEditor.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 8/12/26.
//

import SwiftUI

struct CustomAspectRatioEditor: View {
    
#if os(macOS)
    let labelWidth: CGFloat = 80
    let buttonWidth: CGFloat = 140
#else
    let labelWidth: CGFloat = 110
    let buttonWidth: CGFloat = 160
#endif
    
    let textFieldWidth: CGFloat = 80
    
    enum FocusedField {
        case name
        case width
        case height
        case multiplier
        case pixelWidth
        case pixelHeight
    }
    
    @State private var errorMessage = ""
    @State private var aspectName: String = "Custom"
    
    @State private var aspectWidth: Int = 1
    
    @State private var aspectHeight: Int = 1
    
    @State private var aspectMultiplier: Int = 1920
    
    @State private var pixelWidth: Int = 1920
    
    @State private var pixelHeight: Int = 1920
    
    
    @FocusState private var focusedField: FocusedField?
    @State private var selection: TextSelection?

    
    var dismissClosure: (() -> Void)?
    
    @State private var numberFormatter: NumberFormatter = {
        var nf = NumberFormatter()
        nf.numberStyle = .none
        nf.maximumFractionDigits = 0
        nf.maximum = 16384
        nf.minimum = 1
        return nf
    }()

    func handleField(_ field: FocusedField?) {
    }
    
    var body: some View {
        
        let aspectWidthBinding = Binding(
            get: { String(self.aspectWidth) },
            set: {
                if let newValue = numberFormatter.number(from: $0) { self.aspectWidth = newValue.intValue
                }
            }
        )

        let aspectHeightBinding = Binding(
            get: { String(self.aspectHeight) },
            set: {
                if let newValue = numberFormatter.number(from: $0) { self.aspectHeight = newValue.intValue
                }
            }
        )
        let aspectMultiplierBinding = Binding(
            get: { String(self.aspectMultiplier) },
            set: {
                if let newValue = numberFormatter.number(from: $0) { self.aspectMultiplier = newValue.intValue
                }
            }
        )
        
        let pixelWidthBinding = Binding(
            get: { String(self.pixelWidth) },
            set: {
                if let newValue = numberFormatter.number(from: $0) { self.pixelWidth = newValue.intValue
                }
            }
        )
        
        let pixelHeightBinding = Binding(
            get: { String(self.pixelHeight) },
            set: {
                if let newValue = numberFormatter.number(from: $0) { self.pixelHeight = newValue.intValue
                }
            }
        )

        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Spacer()
                Text("Custom Aspect Ratio")
                    .frame(alignment: .center)
                Spacer()
            }
            
            Spacer()
            HStack {
                Text("Name")
                    .frame(width: labelWidth, alignment: .leading)
                TextField("", text: $aspectName, selection: $selection)
                    .padding(.trailing, 20)
                    .frame(width: 200)
                    .focused($focusedField, equals: .name)
                    .onSubmit {
                        handleField(focusedField)
                    }
                    .onChange(of: focusedField) {
                        if focusedField == .name {
                            selection = .init(range: aspectName.startIndex..<aspectName.endIndex)
                        }
                    }
            }
            HStack {
                Text ("Width")
                    .frame(width: labelWidth, alignment: .leading)
                TextField("", text: aspectWidthBinding, selection: $selection)
                    .padding(.trailing, 20)
                    .frame(width: textFieldWidth)
                    .focused($focusedField, equals: .width)
                    .onSubmit {
                        handleField(focusedField)
                    }
                    .onChange(of: focusedField) {
                        if focusedField == .width {
                            selection = .init(range: aspectWidthBinding.wrappedValue.startIndex..<aspectWidthBinding.wrappedValue.endIndex)
                        }
                    }
                Text ("Height")
                    .frame(width: labelWidth, alignment: .leading)
                TextField("", text: aspectHeightBinding, selection: $selection)
                    .padding(.trailing, 20)
                    .frame(width: textFieldWidth)
                    .focused($focusedField, equals: .height)
                    .onSubmit {
                        handleField(focusedField)
                    }
                    .onChange(of: focusedField) {
                        if focusedField == .height {
                            selection = .init(range: aspectHeightBinding.wrappedValue.startIndex..<aspectHeightBinding.wrappedValue.endIndex)
                        }
                    }
            }
            /*
             .onChange(of: focusedField) {
                 if focusedField == .xxx {
                     selection = .init(range: xxxBinding.wrappedValue.startIndex..<xxxBinding.wrappedValue.endIndex)
                 }
             }

             */
            HStack {
                Text("Multiplier")
                    .frame(width: labelWidth, alignment: .leading)
                TextField("", text: aspectMultiplierBinding, selection: $selection)
                    .padding(.trailing, 20)
                    .frame(width: textFieldWidth)
                    .focused($focusedField, equals: .multiplier)
                    .onSubmit {
                        handleField(focusedField)
                    }
                    .onChange(of: focusedField) {
                        if focusedField == .multiplier {
                            selection = .init(range: aspectMultiplierBinding.wrappedValue.startIndex..<aspectMultiplierBinding.wrappedValue.endIndex)
                        }
                    }
                Text("")
                    .frame(width: labelWidth)
                Text("")
                    .frame(width: textFieldWidth)
                Button("Calculate pixels") {
                    let newAspect = calcAspectAndMultiplier(width:  aspectWidth, height: aspectHeight)
                    aspectWidth = Int(newAspect.width)
                    aspectHeight = Int(newAspect.height)
                    pixelWidth = aspectWidth * aspectMultiplier
                    pixelHeight = aspectHeight * aspectMultiplier
                }
                .frame(width: buttonWidth)
                .padding(.leading, 20)

            }
            HStack {
                Text ("Pixel width")
                    .frame(width: labelWidth, alignment: .leading)
                TextField("", text: pixelWidthBinding, selection: $selection)
                    .padding(.trailing, 20)
                    .frame(width: textFieldWidth)
                    .focused($focusedField, equals: .pixelWidth)
                    .onSubmit {
                        handleField(focusedField)
                    }
                    .onChange(of: focusedField) {
                        if focusedField == .pixelWidth {
                            selection = .init(range: pixelWidthBinding.wrappedValue.startIndex..<pixelWidthBinding.wrappedValue.endIndex)
                        }
                    }
                Text ("Pixel height")
                    .frame(width: labelWidth, alignment: .leading)
                TextField("", text: pixelHeightBinding, selection: $selection)
                    .padding(.trailing, 20)
                    .frame(width: textFieldWidth)
                    .focused($focusedField, equals: .pixelHeight)
                    .onSubmit {
                        handleField(focusedField)
                    }
                    .onChange(of: focusedField) {
                        if focusedField == .pixelHeight {
                            selection = .init(range: pixelHeightBinding.wrappedValue.startIndex..<pixelHeightBinding.wrappedValue.endIndex)
                        }
                    }
                Button("Calculate aspect") {
                    let newAspect = calcAspectAndMultiplier(width: pixelWidth, height: pixelHeight)
                    aspectWidth = Int(newAspect.width)
                    aspectHeight = Int(newAspect.height)
                    aspectMultiplier = Int(newAspect.multiplier)
                }
                .frame(width: buttonWidth)
                .padding(.leading, 20)
            }
            Spacer()
            HStack {
                Spacer()
                Button("Dismiss") {
                    dismissClosure?()
                }
                Spacer()
                Button("Save") {
                    guard aspectWidth * aspectMultiplier <= 16384 && aspectHeight * aspectMultiplier <= 16384 else {
                        errorMessage = "Pixel dimensions too large!"
                        return
                    }
                    let aspect = AspectRatio(
                        title: aspectName,
                        width: Double(aspectWidth),
                        height: Double(aspectHeight),
                        defaultMultiplier: aspectMultiplier,
                        index: 0,
                    isCropForTiling: false)
                    SettingsView.saveCustomAspectRatio(aspect)
                    dismissClosure?()
                }
                Spacer()
            }
            Text(errorMessage)
                .foregroundColor(.red)
        }
        .onChange(of: focusedField) { oldValue, newValue in
            handleField(oldValue)
        }
        .onAppear() {
            focusedField = .name
        }
        .padding(.all, 20)
    }
}

#Preview {
    CustomAspectRatioEditor()
}
