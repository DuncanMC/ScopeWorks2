//
//  ExternalDisplayManager.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 7/15/26.
//

import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif


let displaysChangedNotification = Notification.Name("ScopeStateRelocationReady")
let closingFullScreenNotification = Notification.Name("closingFullScreen")


struct DisplayInfo: Identifiable, Hashable, CustomStringConvertible {
    let id: String
    let name: String
    let size: CGSize?
    let scale: CGFloat
    var aspect: AspectAndMultiplier? {
        guard let size else { return nil }
        return calcAspectAndMultiplier(width: Int(size.width), height: Int(size.height))
    }
    var description: String {
        return "Display \"\(name)\" (\(Int((size?.width ?? 0) * scale))x\(Int((size?.height ?? 0) * scale))). Aspect \(Int(aspect?.width ?? 0)):\(Int(aspect?.height ?? 0)). Scale = \(scale)"
    }
}

final class ExternalDisplayManager {
    static let shared = ExternalDisplayManager()
    
    static var availableDisplays: [DisplayInfo] = []
    
    private init() {
        setupNotifications()
    }
    
    
    public func refreshDisplayList() {
#if os(macOS)
        ExternalDisplayManager.availableDisplays = NSScreen.screens
            .compactMap { screen in
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return nil
            }
            return DisplayInfo(
                id: String(screenNumber),
                name: screen.localizedName,
                size: screen.frame.size,
                scale: screen.backingScaleFactor
            )
        }
#else
        var displays: [DisplayInfo] = []
        // Always include the built-in screen
        displays.append(DisplayInfo(
            id: "0",
            name: UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone",
            size: UIScreen.main.bounds.size,
            scale: UIScreen.main.scale)
        )
        // Add any external display scenes (AirPlay, HDMI, etc.)
        let externalScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.session.role == .windowExternalDisplayNonInteractive }
        for (index, scene) in externalScenes.enumerated() {
            displays.append(DisplayInfo(
                id: "ext-\(index)",
                name: "AirPlay Display \(index + 1)",
                size: scene.coordinateSpace.bounds.size,
                scale: scene.screen.scale))
        }
        ExternalDisplayManager.availableDisplays = displays
#endif
//        for aDisplay in ExternalDisplayManager.availableDisplays {
//            print(aDisplay.description)
//        }
        NotificationCenter.default.post(name: displaysChangedNotification, object: nil)

    }
    
    private func setupNotifications() {
#if os(macOS)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshDisplayList()
            }
        }
#else
        NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshDisplayList()
            }
        }
        NotificationCenter.default.addObserver(
            forName: UIScene.didDisconnectNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshDisplayList()
            }
        }
#endif
    }
}
