//
//  CameraManager.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 7/3/26.
//

@preconcurrency import AVFoundation
import Combine
import Metal
import CoreVideo
#if os(iOS)
import UIKit
#endif

@MainActor
class CameraManager: NSObject, ObservableObject {

    // MARK: - Published properties for UI binding
    @Published var availableDevices: [AVCaptureDevice] = []
    @Published var selectedDeviceID: String?
    @Published var isRunning: Bool = false
    @Published var permissionStatus: AVAuthorizationStatus = .notDetermined

    // MARK: - Private capture properties
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var currentInput: AVCaptureDeviceInput?

    // MARK: - Metal texture cache (written once in init, read from capture queue)
    nonisolated(unsafe) private var textureCache: CVMetalTextureCache?
    private var metalDevice: MTLDevice?

    // MARK: - Callback target
    private weak var scopeState: ScopeState?

    // Retain the CVMetalTexture so the MTLTexture's backing store stays valid
    private var currentCVTexture: CVMetalTexture?

    // MARK: - Serial queue for capture delegate
    private let captureQueue = DispatchQueue(label: "com.wareto.scopeworks2.camera", qos: .userInteractive)

    // MARK: - Init
    init(metalDevice: MTLDevice, scopeState: ScopeState) {
        self.metalDevice = metalDevice
        self.scopeState = scopeState
        super.init()

        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, metalDevice, nil, &cache)
        self.textureCache = cache

        refreshDeviceList()

#if os(iOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pauseSession()
            }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.resumeSession()
            }
        }
#endif
    }

    // MARK: - Device Discovery
    func refreshDeviceList() {
#if os(macOS)
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
#else
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTripleCamera, .builtInUltraWideCamera],
            mediaType: .video,
            position: .unspecified
        )
#endif
        availableDevices = discoverySession.devices
    }

    // MARK: - Permission
    func requestPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        permissionStatus = status
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permissionStatus = granted ? .authorized : .denied
            return granted
        default:
            return false
        }
    }

    // MARK: - Start Camera
    func startCamera(deviceID: String? = nil) async {
        guard await requestPermission() else { return }

        stopCamera()

        let session = AVCaptureSession()
        session.sessionPreset = .high

        // Select device
        let device: AVCaptureDevice?
        if let deviceID = deviceID {
            device = AVCaptureDevice(uniqueID: deviceID)
        } else {
#if os(macOS)
            device = AVCaptureDevice.default(for: .video)
#else
            device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
#endif
        }

        guard let captureDevice = device,
              let input = try? AVCaptureDeviceInput(device: captureDevice) else {
            print("CameraManager: Could not create device input")
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
            currentInput = input
        }

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: captureQueue)

        if session.canAddOutput(output) {
            session.addOutput(output)
        }

#if os(iOS)
        if let connection = output.connection(with: .video) {
            connection.videoRotationAngle = currentVideoRotationAngle()
        }

        // Update rotation when device orientation changes
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self,
                      let connection = self.videoOutput?.connection(with: .video) else { return }
                let angle = self.currentVideoRotationAngle()
                if connection.videoRotationAngle != angle {
                    connection.videoRotationAngle = angle
                }
            }
        }
#endif

        captureSession = session
        videoOutput = output
        selectedDeviceID = captureDevice.uniqueID

        captureQueue.async {
            session.startRunning()
        }
        isRunning = true
    }

    // MARK: - Stop Camera
    func stopCamera() {
        let session = captureSession
        captureQueue.async {
            session?.stopRunning()
        }
        captureSession?.inputs.forEach { captureSession?.removeInput($0) }
        captureSession?.outputs.forEach { captureSession?.removeOutput($0) }
        captureSession = nil
        currentInput = nil
        videoOutput = nil
        isRunning = false
    }

    // MARK: - Video Rotation (iOS)
#if os(iOS)
    private func currentVideoRotationAngle() -> CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            return 0  // default to landscape
        }
        switch windowScene.interfaceOrientation {
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return 270
        case .landscapeLeft:
            return 180
        case .landscapeRight:
            return 0
        default:
            return 0
        }
    }
#endif

    // MARK: - Pause / Resume (iOS background)
    private func pauseSession() {
        let session = captureSession
        captureQueue.async {
            session?.stopRunning()
        }
    }

    private func resumeSession() {
        guard isRunning else { return }
        let session = captureSession
        captureQueue.async {
            session?.startRunning()
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let textureCache = textureCache else { return }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            nil,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )

        guard status == kCVReturnSuccess,
              let cvTex = cvTexture,
              let metalTexture = CVMetalTextureGetTexture(cvTex) else {
            return
        }

        Task { @MainActor [weak self] in
            self?.currentCVTexture = cvTex  // Retain backing store
            self?.scopeState?.texture = metalTexture
        }
    }
}
