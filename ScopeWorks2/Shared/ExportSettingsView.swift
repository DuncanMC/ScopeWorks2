//
//  ExportSettingsView.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 7/17/26.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

/// Shared state for image/video export settings panels.
class ExportSettingsState: ObservableObject {
    @Published var selectedFormat: SnapshotFormat = .PNG
    @Published var selectedAspectRatio: AspectRatio
    @Published var exportWidth: Int = 1920
    @Published var exportHeight: Int = 1080
    
    var isEightWayScope: Bool

    init(defaultAspectRatio: AspectRatio, isEightWayScope: Bool) {
        print("In ExportSettingsState.init. isEightWayScope = \(isEightWayScope)")
        self.selectedAspectRatio = defaultAspectRatio
        self.isEightWayScope = isEightWayScope
        updateHeightFromWidth()
    }

    func updateHeightFromWidth() {
        guard selectedAspectRatio.width > 0 else { return }
        let ratio = (isEightWayScope && selectedAspectRatio.isCropForTiling) ? 1 : selectedAspectRatio.height / selectedAspectRatio.width
        let newHeight = max(1, Int(round(Double(exportWidth) * ratio)))
        guard newHeight != exportHeight else { return }
        exportHeight = newHeight
    }

    func updateWidthFromHeight() {
        guard selectedAspectRatio.height > 0 else { return }
        let ratio = (isEightWayScope && selectedAspectRatio.isCropForTiling) ? 1 : selectedAspectRatio.width / selectedAspectRatio.height
        let newWidth = max(1, Int(round(Double(exportHeight) * ratio)))
        guard newWidth != exportWidth else { return }
        exportWidth = newWidth
    }
}

/// Reusable form for configuring image/video export settings.
/// Used as an NSSavePanel accessory view (macOS) or in a sheet (iOS).
struct ExportSettingsView: View {
    @ObservedObject var settings: ExportSettingsState
    let isForVideo: Bool
    @FocusState private var focusedField: DimensionField?

    enum DimensionField {
        case width, height
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !isForVideo {
                HStack {
                    Text("Format:")
                        .frame(width: 90, alignment: .trailing)
                    Picker("", selection: $settings.selectedFormat) {
                        ForEach(SnapshotFormat.allCases, id: \.self) { format in
                            Text(format.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }
            }

            HStack {
                Text("Aspect Ratio:")
                    .frame(width: 90, alignment: .trailing)
                Picker("", selection: $settings.selectedAspectRatio) {
                    ForEach(SettingsView.allAspectRatios()) { ratio in
                        Text(ratio.title).tag(ratio)
                    }
                }
                .labelsHidden()
                .frame(width: 180)
                .onChange(of: settings.selectedAspectRatio) {
                    settings.updateHeightFromWidth()
                }
            }

            HStack {
                Text("Width:")
                    .frame(width: 90, alignment: .trailing)
                TextField("Width", value: $settings.exportWidth, format: .number)
                    .frame(width: 80)
                    .focused($focusedField, equals: .width)
                    .onSubmit { settings.updateHeightFromWidth() }
                    .onChange(of: settings.exportWidth) {
                        if focusedField == .width {
                            settings.updateHeightFromWidth()
                        }
                    }
                Text("px")
            }

            HStack {
                Text("Height:")
                    .frame(width: 90, alignment: .trailing)
                TextField("Height", value: $settings.exportHeight, format: .number)
                    .frame(width: 80)
                    .focused($focusedField, equals: .height)
                    .onSubmit { settings.updateWidthFromHeight() }
                    .onChange(of: settings.exportHeight) {
                        if focusedField == .height {
                            settings.updateWidthFromHeight()
                        }
                    }
                Text("px")
            }
        }
        .padding()
        .frame(minWidth: 320)
    }
}
