//
//  ScopeTypePicker.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 4/3/26.
//

import SwiftUI

struct ScopeTypePicker: View {
    
    var scopeTypePickerLeading: CGFloat {
        #if os(macOS)
            return 14
        #else
            return 45
        #endif
    }

    var scopeTypeTitleLeading: CGFloat {
        #if os(macOS)
            return 12
        #else
            return 7
        #endif
    }
    var title: String
    var options: [ScopeTypeNameAndIndex]
    @Binding var selection: ScopeType {
        didSet {
            if selectionIndex != selection.rawValue {
                selectionIndex = selection.rawValue
            }
        }
    }
    @State private var selectionIndex: Int = 0

    var body: some View {
        HStack {
            Text(title)
                .frame(minWidth: 140, alignment: .leading)
                .padding(.leading, scopeTypeTitleLeading)
            Picker(title, selection: $selectionIndex) {
                ForEach(options, id: \.self.index) { option in
                    Text("\(option.title)")
                        .frame(minWidth: 150, alignment: .leading)
                }
            }
            .onChange(of: selectionIndex) {
                if let scopeType = ScopeType(rawValue: selectionIndex) {
                    selection = scopeType
                }
            }
            .labelsHidden()
            .frame(minWidth: 150, alignment: .leading)
            .padding(.leading, scopeTypePickerLeading) //xxx
            Spacer()
        }
            .frame(maxHeight: 25)
            .frame(minWidth: 250)
            .onAppear {
                if selectionIndex != selection.rawValue {
                    selectionIndex = selection.rawValue
                }
            }
    }
}


