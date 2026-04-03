//
//  ScopeTypePicker.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 4/3/26.
//

import SwiftUI

struct ScopeTypePicker: View {
    
    var title: String
    var options: [String]
    @Binding var selection: Int

    var body: some View {
        Picker(selection: $selection, label:
                
                HStack {
            Rectangle()
#if os(macOS)
                .foregroundColor(Color(nsColor: .windowBackgroundColor))
#else
                .foregroundColor(Color(uiColor: .systemBackground))
#endif
                .frame(height: 40)
//            Text(title)
//            Image(systemName: "chevron.down")
//                .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 8))
        }
//            .overlay(
//                RoundedRectangle(cornerRadius: 5)
//                    .stroke(Color.black, lineWidth: 1)
//            )
                .overlay(
                    Text("Picker Option \(options[selection])")
                )
                    .padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        ) {
            ForEach(options, id: \.self) { option in
                Text("Picker Option \(option)")
            }
        }
        .pickerStyle(MenuPickerStyle())
    }
}


