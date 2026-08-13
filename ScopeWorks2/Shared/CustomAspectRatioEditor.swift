//
//  CustomAspectRatioEditor.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 8/12/26.
//

import SwiftUI

struct CustomAspectRatioEditor: View {
    
    let labelWidth: CGFloat = 80
    
    let textFieldWidth: CGFloat = 80
    let buttonWidth: CGFloat = 140
    
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
        switch field {
        case .name:
            print("Parse name")
        case .width:
            print("Parse width")
        case .height:
            print("Parse height")
        case .multiplier:
            print("Parse multiplier")
        case .pixelWidth:
            print("Parse pixelWidth")
        case .pixelHeight:
            print("Parse pixelHeight")
        case nil:
            print("handleField called with nil")

        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Custom Aspect Ratio")
            
            Spacer()
            HStack {
                Text("Name")
                    .frame(width: labelWidth, alignment: .leading)
                TextField("", text: $aspectName)
                    .padding(.trailing, 20)
                    .frame(width: 200)
                    .focused($focusedField, equals: .name)
                    .onSubmit {
                        handleField(focusedField)
                    }
            }
            HStack {
                Text ("Width")
                    .frame(width: labelWidth, alignment: .leading)
                TextField("", value: $aspectWidth, formatter: numberFormatter)
                    .padding(.trailing, 20)
                    .frame(width: textFieldWidth)
                    .focused($focusedField, equals: .width)
                    .onSubmit {
                        handleField(focusedField)
                    }
                Text ("Height")
                    .frame(width: labelWidth, alignment: .leading)
                TextField("", value: $aspectHeight, formatter: numberFormatter)
                    .padding(.trailing, 20)
                    .frame(width: textFieldWidth)
                    .focused($focusedField, equals: .height)
                    .onSubmit {
                        handleField(focusedField)
                    }
            }
            HStack {
                Text("Multiplier")
                    .frame(width: labelWidth, alignment: .leading)
                TextField("", value: $aspectMultiplier, formatter: numberFormatter)
                    .padding(.trailing, 20)
                    .frame(width: textFieldWidth)
                    .focused($focusedField, equals: .multiplier)
                    .onSubmit {
                        handleField(focusedField)
                    }
                Text("")
                    .frame(width: labelWidth)
                Text("")
                    .frame(width: textFieldWidth)
                Button("Calculate pixels") {
                    print("Calculating pixels")
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
                TextField("", value: $pixelWidth, formatter: numberFormatter)
                    .padding(.trailing, 20)
                    .frame(width: textFieldWidth)
                    .focused($focusedField, equals: .pixelWidth)
                    .onSubmit {
                        handleField(focusedField)
                    }
                Text ("Pixel height")
                    .frame(width: labelWidth, alignment: .leading)
                TextField("", value: $pixelHeight, formatter: numberFormatter)
                    .padding(.trailing, 20)
                    .frame(width: textFieldWidth)
                    .focused($focusedField, equals: .pixelHeight)
                    .onSubmit {
                        handleField(focusedField)
                    }
                Button("Calculate aspect") {
                    print("Calculating aspect")
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
                        print("Pixel dimensions too large!")
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
        .padding(.all, 20)
    }
}

#Preview {
    CustomAspectRatioEditor()
}
