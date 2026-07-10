//
//  SettingsView.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 7/3/26.
//

import SwiftUI
import UniformTypeIdentifiers


enum SnapshotFormat: String, CaseIterable {
    case JPEG, PNG, TIFF
    
    var fileType: UTType? {
        return UTType(filenameExtension: self.rawValue)
    }
}

var settingsChangedNotification = Notification.Name(rawValue: "settingsChanged")


enum UserDefaultsKeys: String {
    case snapshotFileType
}


struct SettingsView: View {
    
    init(doneButtonAction: @escaping () -> Void) {
        self.doneButtonAction = doneButtonAction
        let snapshotFileType = UserDefaults.standard.integer(forKey: UserDefaultsKeys.snapshotFileType.rawValue)
        self.snapshotFileType = snapshotFileType
        self.selection = snapshotFileType
        
    }
    
    var doneButtonAction: () -> Void
    
    
    @AppStorage(UserDefaultsKeys.snapshotFileType.rawValue) var snapshotFileType: Int = UserDefaults.standard.integer(forKey: UserDefaultsKeys.snapshotFileType.rawValue)


    var snapshotTypePickerLeading: CGFloat {
        #if os(macOS)
            return 14
        #else
            return 45
        #endif
    }

    var snapshotTypeTitleLeading: CGFloat {
        #if os(macOS)
            return 12
        #else
            return 7
        #endif
    }

    @State var selection: Int
    
    var options: [(title: String, index: Int)] = {
        SnapshotFormat.allCases.enumerated().map {
            ($0.element.rawValue, $0.offset)
        }
    }()

    var body: some View {
        ZStack {
            VStack(alignment: .center) {
                #if os(iOS)
                    Text("Settings")
                        .padding(.top, 20)
                #endif
                Spacer()
                VStack(alignment: .leading, spacing: 30) {
                    Text("Snork")
                        .padding([.leading, .trailing], 50)
                    HStack {
                        Text("Snapshot filetype")
                            .frame(minWidth: 140, alignment: .leading)
                            .padding(.leading, snapshotTypeTitleLeading)
                        Picker("", selection: $selection) {
                            ForEach(options, id: \.self.index) { option in
                                Text("\(option.title)")
                                    .frame(minWidth: 150, alignment: .leading)
                            }
                        }
                        .onChange(of: selection) {
                            snapshotFileType = selection
                            UserDefaults.standard.set(snapshotFileType, forKey: UserDefaultsKeys.snapshotFileType.rawValue)
                            let center = NotificationCenter.default
                            let userInfo = [UserDefaultsKeys.snapshotFileType.rawValue:  snapshotFileType]
                            center.post(name: settingsChangedNotification, object: nil, userInfo: userInfo)
                        }
                        .labelsHidden()
                        .frame(minWidth: 150, alignment: .leading)
                        .padding(.leading, snapshotTypePickerLeading) //xxx
                        Spacer()
                    }
                        .frame(maxHeight: 25)
                        .frame(minWidth: 250)

                }
                Spacer()
                Spacer()
            }
#if os(iOS)
            VStack {
                Spacer()
                Button("Done") {
                    doneButtonAction()
                }
                .padding(.bottom, 20)
            }
#endif

        }    }
}

//#Preview {
//    SettingsView()
//}
