//
//  VideoRecordingControlsView.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 7/17/26.
//

import SwiftUI

/// Floating overlay showing recording state, elapsed time, and play/pause/stop controls.
struct VideoRecordingControlsView: View {
    @ObservedObject var recorder: VideoRecorder
    var onStop: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Recording state indicator
            Circle()
                .fill(recorder.state == .recording ? .red : .gray)
                .frame(width: 12, height: 12)

            // Elapsed time
            Text(timeString(from: recorder.elapsedTime))
                .monospacedDigit()
                .frame(minWidth: 60)

            // Record / Pause toggle
            Button {
                if recorder.state == .recording {
                    recorder.pause()
                } else if recorder.state == .paused {
                    recorder.resume()
                }
            } label: {
                Image(systemName: recorder.state == .recording ? "pause.fill" : "record.circle")
                    .font(.title2)
            }
            .disabled(recorder.state != .recording && recorder.state != .paused)

            // Stop button
            Button {
                Task {
                    await recorder.stop()
                    onStop()
                }
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title2)
            }
            .disabled(recorder.state == .idle || recorder.state == .stopping)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 4)
    }

    private func timeString(from interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
