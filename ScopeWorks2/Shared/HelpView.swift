//
//  HelpView.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 8/7/26.
//

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var helpString: LocalizedStringKey {
        let noHelpAvailableString = LocalizedStringKey("No Help Available")
        guard let helpStringURL = Bundle.main.url(forResource: "help", withExtension: "md") else {
            return noHelpAvailableString
        }
        do {
            return LocalizedStringKey(try String(contentsOf: helpStringURL, encoding: .utf8))
        }
        catch {
            return noHelpAvailableString
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing:20) {
            HStack {
                Spacer()
                Text("ScopeWorks Help")
                    .multilineTextAlignment(.center)
                    .font(Font.title.bold())
                    .padding([.top, .leading, .trailing], 20)
                Spacer()
            }

            ScrollView(.vertical, showsIndicators: true) {
                Text(helpString)
                    .padding([.leading, .trailing], 20)
            }
            Spacer()
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .padding([.bottom, .trailing], 20)
            }
        }
        // The ideal size drives the sheet size on both platforms:
        // macOS sheets follow the content frame directly, and
        // .presentationSizing(.fitted) makes the iPad sheet adopt the
        // content's ideal size instead of the fixed page-sheet width.
        .frame(minWidth: 700, idealWidth: 1200, maxWidth: .infinity,
               minHeight: 500, idealHeight: 700, maxHeight: .infinity)
        .presentationSizing(.fitted)
    }
}

#Preview {
    HelpView()
}
