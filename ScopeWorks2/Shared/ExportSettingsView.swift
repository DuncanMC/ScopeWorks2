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

    /// The largest texture dimension the GPU supports. Exporting beyond this crashes,
    /// so we surface the limit to the user and block exports that exceed it.
    let maxTextureSize = ScopeState.getMaxTextureSize()

    /// True when the requested export size exceeds the GPU's maximum texture size.
    var exceedsMaxTextureSize: Bool {
        exportWidth > maxTextureSize || exportHeight > maxTextureSize
    }

    /// The H.264 encoder rejects frames larger than the level 6.2 limit of
    /// 139,264 macroblocks (16×16 pixel blocks) — about 35.6 megapixels total,
    /// e.g. 5968×5968 or 8192×4352. The limit is on total frame area, not on
    /// either dimension individually. Exceeding it fails with
    /// kVTVideoEncoderMalfunctionErr (-10279) when the movie is finalized.
    static let maxH264MacroblocksPerFrame = 139_264

    /// True when the requested size exceeds what the H.264 video encoder accepts
    /// (or the GPU's texture limit, which still applies to the render pass).
    var exceedsMaxVideoSize: Bool {
        exceedsMaxTextureSize ||
        ((exportWidth + 15) / 16) * ((exportHeight + 15) / 16) > Self.maxH264MacroblocksPerFrame
    }

    /// The largest export size matching the current aspect ratio that the
    /// H.264 encoder (and GPU) will accept.
    var maxVideoSize: (width: Int, height: Int) {
        let ratio = heightToWidthRatio
        guard ratio > 0 else { return (maxTextureSize, maxTextureSize) }
        // Start from the pixel-budget estimate, then step down until both the
        // macroblock and texture limits are satisfied.
        var width = Int((Double(Self.maxH264MacroblocksPerFrame) * 256.0 / ratio).squareRoot()) + 16
        width = min(width, maxTextureSize)
        while width > 1 {
            let height = max(1, Int(round(Double(width) * ratio)))
            if height <= maxTextureSize &&
                ((width + 15) / 16) * ((height + 15) / 16) <= Self.maxH264MacroblocksPerFrame {
                return (width, height)
            }
            width -= 1
        }
        return (1, 1)
    }

    /// Height as a fraction of width for the current aspect ratio.
    private var heightToWidthRatio: Double {
        guard selectedAspectRatio.width > 0 else { return 0 }
        return (isEightWayScope && selectedAspectRatio.isCropForTiling)
            ? 1 : selectedAspectRatio.height / selectedAspectRatio.width
    }

    var isEightWayScope: Bool

    init(defaultAspectRatio: AspectRatio, isEightWayScope: Bool) {
        print("In ExportSettingsState.init. isEightWayScope = \(isEightWayScope)")
        self.selectedAspectRatio = defaultAspectRatio
        self.isEightWayScope = isEightWayScope
        updateHeightFromWidth(aspectChanged: true)
    }

    func updateHeightFromWidth(aspectChanged: Bool) {
        guard selectedAspectRatio.width > 0 else { return }
        let ratio = (isEightWayScope && selectedAspectRatio.isCropForTiling) ? 1 : selectedAspectRatio.height / selectedAspectRatio.width
        let aspect = selectedAspectRatio.activeMultipler ?? selectedAspectRatio.defaultMultiplier
        let adjustedWidth = aspectChanged ? Int(selectedAspectRatio.width * Double(aspect)) : exportWidth
        exportWidth = adjustedWidth
        let newHeight = max(1, Int(round(Double(adjustedWidth) * ratio)))
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
                    settings.updateHeightFromWidth(aspectChanged: true)
                }
            }

            HStack {
                Text("Width:")
                    .frame(width: 90, alignment: .trailing)
                TextField("Width", value: $settings.exportWidth, format: .number)
                    .frame(width: 80)
                    .focused($focusedField, equals: .width)
                    .onSubmit {
                        settings.updateHeightFromWidth(aspectChanged: false)
                    }
                    .onChange(of: settings.exportWidth) {
                        if focusedField == .width {
                            settings.updateHeightFromWidth(aspectChanged: false)
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

            if isForVideo {
                let maxSize = settings.maxVideoSize
                Text("Maximum video size for this aspect ratio: \(maxSize.width)×\(maxSize.height) px")
                    .font(.footnote)
                    .foregroundStyle(settings.exceedsMaxVideoSize ? Color.red : Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text("Maximum width/height: \(settings.maxTextureSize) px")
                    .font(.footnote)
                    .foregroundStyle(settings.exceedsMaxTextureSize ? Color.red : Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
        .frame(minWidth: 320)
    }
}
