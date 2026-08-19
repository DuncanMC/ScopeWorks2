//
//  AboutView.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 8/17/26.
//

import SwiftUI

struct AboutView: View
{
    @Environment(\.dismiss) private var dismiss

    static var aboutString: LocalizedStringKey {
        let noAboutInfoAvailableString = LocalizedStringKey("No About Info Available")
        guard let aboutStringURL = Bundle.main.url(forResource: "about", withExtension: "md") else {
            return noAboutInfoAvailableString
        }
        do {
            return LocalizedStringKey(try String(contentsOf: aboutStringURL, encoding: .utf8))
        }
        catch {
            return noAboutInfoAvailableString
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing:20) {
            HStack {
                Spacer()
                Text("About ScopeWorks")
                    .multilineTextAlignment(.center)
                    .font(Font.title.bold())
                    .padding([.top, .leading, .trailing], 20)
                    .padding(.bottom, 20)
                Spacer()
            }

            ScrollView(.vertical, showsIndicators: true) {
                Text(AboutView.aboutString)
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
                Spacer()
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
    AboutView()
}


