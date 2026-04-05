//
//  ScopeTypePicker.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 4/3/26.
//

import SwiftUI

struct ScopeTypePicker: View {
    
    var title: String
    var options: [(title: String, index: Int)]
    @Binding var selection: Int

    var body: some View {
            List {
                Picker(title, selection: $selection) {
                    ForEach(options, id: \.self.index) { option in
                        Text("\(option.title)")
                    }
                }
            }
            .frame(height: 100)
            .border(.black, width: 2)
            .frame(minWidth: 250)


            /*
             Text(title)
            Picker(selection: $selection, label:
                    HStack {
                        Rectangle()
                        #if os(macOS)
                            .foregroundColor(Color(nsColor: .windowBackgroundColor))
                        #else
                            .foregroundColor(Color(uiColor: .systemBackground))
                        #endif
                            .frame(height: 40)
                        
                    }
                .overlay(
                    Text("\(options[selection].title)")
                )
                    .padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

            ) {
                ForEach(options, id: \.self.index) { option in
                    Text("\(option.title)")
                }
            }
            .pickerStyle(MenuPickerStyle())
            */
//            .overlay(
//                RoundedRectangle(cornerRadius: 16)
//                    .stroke(.blue, lineWidth: 2)
//            )
            

        
    }
}


