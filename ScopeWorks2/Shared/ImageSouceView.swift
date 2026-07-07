//
//  ImageSouceView.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 7/3/26.
//

import SwiftUI
import AVFoundation

struct ImageSouceView: View {

    @ObservedObject var scopeState: ScopeState
    @StateObject private var cameraManager: CameraManager

    var imageSourceLeading: CGFloat {
        #if os(macOS)
            return 1
        #else
            return 10
        #endif
    }

    var dismissClosure: (() -> Void)

    init(scopeState: ScopeState, dismissClosure: @escaping () -> Void) {
        self.scopeState = scopeState
        self.dismissClosure = dismissClosure

        // Create or reuse the CameraManager so its @Published properties drive the UI
        if let existing = scopeState.cameraManager {
            _cameraManager = StateObject(wrappedValue: existing)
        } else {
            let device = MTLCreateSystemDefaultDevice()!
            let manager = CameraManager(metalDevice: device, scopeState: scopeState)
            scopeState.cameraManager = manager
            _cameraManager = StateObject(wrappedValue: manager)
        }
    }

    var body: some View {
        VStack(spacing: 30) {
            Text("Image Source")
                .font(.headline)
                .padding([.leading, .trailing], 50)
            Spacer()

            // Static image picker
            PhotoPickerView(scopeState: scopeState, dismissClosure: {
                scopeState.switchToStaticImage()
                dismissClosure()
            })
            .frame(minWidth: 120)
            .padding(.leading, imageSourceLeading)

#if os(macOS)
            // macOS: List all available cameras
            if !cameraManager.availableDevices.isEmpty {
                Menu("Camera") {
                    ForEach(cameraManager.availableDevices, id: \.uniqueID) { device in
                        Button(device.localizedName) {
                            Task {
                                await scopeState.startCamera(deviceID: device.uniqueID)
                                dismissClosure()
                            }
                        }
                    }
                }
            }
#else
            // iOS: Front and Rear camera buttons
            Button("Front Camera") {
                Task {
                    let frontDevice = AVCaptureDevice.default(
                        .builtInWideAngleCamera, for: .video, position: .front)
                    await scopeState.startCamera(deviceID: frontDevice?.uniqueID)
                    dismissClosure()
                }
            }
            Button("Rear Camera") {
                Task {
                    let rearDevice = AVCaptureDevice.default(
                        .builtInWideAngleCamera, for: .video, position: .back)
                    await scopeState.startCamera(deviceID: rearDevice?.uniqueID)
                    dismissClosure()
                }
            }
#endif

            if scopeState.imageSourceMode != .staticImage {
                Button("Stop Camera") {
                    scopeState.switchToStaticImage()
                }
                .foregroundColor(.red)
            }

            Button("Dismiss") {
                dismissClosure()
            }
            .padding(.bottom, 20)
        }
        .padding(.all, 20)
    }
}

#Preview {
    ImageSouceView(scopeState: ScopeState(), dismissClosure: {})
}
