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
    case folderSetupComplete
    case lastUsedImageDirectoryBookmark
}


struct SettingsView: View {
    
    init(doneButtonAction: @escaping () -> Void) {
        self.doneButtonAction = doneButtonAction
        let snapshotFileType = UserDefaults.standard.integer(forKey: UserDefaultsKeys.snapshotFileType.rawValue)
        self.snapshotFileType = snapshotFileType
        self.selection = snapshotFileType
        
    }
    
    var doneButtonAction: () -> Void
    @State private var showingFolderSetup = false
    
    
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
                    Text("Snapshots")
                        .font(.headline)
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
                        .padding(.leading, snapshotTypePickerLeading)
                        Spacer()
                    }
                        .frame(maxHeight: 25)
                        .frame(minWidth: 250)

                    Divider()
                        .padding(.horizontal, 20)

                    Text("Folders")
                        .font(.headline)
                        .padding([.leading, .trailing], 50)

                    VStack(alignment: .leading, spacing: 8) {
                        folderStatusRow(label: "Source Images", url: FolderBookmarkManager.shared.sourceImagesURL)
                        folderStatusRow(label: "Documents", url: FolderBookmarkManager.shared.documentsURL)
                        folderStatusRow(label: "Snapshots", url: FolderBookmarkManager.shared.snapshotsURL)
                    }
                    .padding(.leading, snapshotTypeTitleLeading)

                    Button("Re-configure Folders...") {
                        showingFolderSetup = true
                    }
                    .padding(.leading, snapshotTypeTitleLeading)
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

        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showingFolderSetup) {
            FirstLaunchSetupView(
                folderManager: FolderBookmarkManager.shared,
                onComplete: {
                    showingFolderSetup = false
                }
            )
        }
        #else
        .sheet(isPresented: $showingFolderSetup) {
            FirstLaunchSetupView(
                folderManager: FolderBookmarkManager.shared,
                onComplete: {
                    showingFolderSetup = false
                }
            )
            .frame(minWidth: 500, minHeight: 400)
        }
        #endif
    }

    private func folderStatusRow(label: String, url: URL?) -> some View {
        HStack {
            Text(label)
                .frame(minWidth: 120, alignment: .leading)
            if let url = url {
                Text(url.lastPathComponent)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Not configured")
                    .foregroundStyle(.red)
            }
        }
    }
}

//#Preview {
//    SettingsView()
//}
