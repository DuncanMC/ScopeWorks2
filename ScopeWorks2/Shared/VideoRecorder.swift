//
//  VideoRecorder.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 7/17/26.
//

import AVFoundation
import Combine
import Metal
import CoreVideo
import SwiftUI

enum RecordingState {
    case idle
    case paused
    case recording
    case stopping
}

/// Records kaleidoscope frames to a video file using AVAssetWriter.
/// Starts in a paused state so the user can adjust settings before recording begins.
class VideoRecorder: ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var elapsedTime: TimeInterval = 0

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var displayLink: CADisplayLink?
    private var frameCount: Int = 0
    private let fps: Int = 30

    let width: Int
    let height: Int
    let outputURL: URL
    let aspectRatio: AspectRatio

    weak var renderer: ScopeRenderer?
    var renderTarget: ScopeRenderer.OffscreenRenderTarget?

    init(width: Int, height: Int, outputURL: URL, renderer: ScopeRenderer, aspectRatio: AspectRatio) {
        self.width = width
        self.height = height
        self.outputURL = outputURL
        self.aspectRatio = aspectRatio
        self.renderer = renderer
        self.renderTarget = renderer.makeOffscreenRenderTarget(width: width, height: height)
    }

    func setup() throws {
        // Remove existing file if present
        try? FileManager.default.removeItem(at: outputURL)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true

        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )

        writer.add(input)

        assetWriter = writer
        videoInput = input
        pixelBufferAdaptor = adaptor

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        state = .recording

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / Double(fps), repeats: true) { [weak self] _ in
            self?.captureFrame()
        }
        // Keep a reference via the run loop (Timer is retained by RunLoop when scheduled)
        RunLoop.current.add(timer, forMode: .common)
        _frameTimer = timer
    }

    func pause() {
        guard state == .recording else { return }
        _frameTimer?.invalidate()
        _frameTimer = nil
        state = .paused
    }

    func stop() async {
        _frameTimer?.invalidate()
        _frameTimer = nil
        state = .stopping

        videoInput?.markAsFinished()
        await assetWriter?.finishWriting()
        state = .idle
    }

    // MARK: - Private

    private var _frameTimer: Timer?

    private func captureFrame() {
        guard state == .recording,
              let input = videoInput,
              let adaptor = pixelBufferAdaptor,
              input.isReadyForMoreMediaData,
              let renderer = renderer,
              let renderTarget = renderTarget else { return }

        guard let pool = adaptor.pixelBufferPool else {
            print("[VideoRecorder] Pixel buffer pool is nil")
            return
        }

        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        guard let buffer = pixelBuffer else { return }

        let success = renderer.renderOffscreenToPixelBuffer(
            pixelBuffer: buffer,
            renderTarget: renderTarget,
            aspectRatio: aspectRatio
        )

        guard success else { return }

        let presentationTime = CMTime(value: CMTimeValue(frameCount), timescale: CMTimeScale(fps))
        adaptor.append(buffer, withPresentationTime: presentationTime)
        frameCount += 1
        elapsedTime = Double(frameCount) / Double(fps)
    }
}
