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


struct DisplayInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let size: CGSize?
    var aspect: AspectAndMultiplier? {
        guard let size else { return nil }
        return calcAspectAndMultiplier(width: Int(size.width), height: Int(size.height))
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
        ExternalDisplayManager.availableDisplays = NSScreen.screens.compactMap { screen in
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return nil
            }
            return DisplayInfo(id: String(screenNumber), name: screen.localizedName, size: screen.frame.size)
            //Add height and width to this screen's displayInfo
        }
#else
        var displays: [DisplayInfo] = []
        // Always include the built-in screen
        displays.append(DisplayInfo(id: "0", name: UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone", size: UIScreen.main.bounds.size))
        // Add any external display scenes (AirPlay, HDMI, etc.)
        let externalScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.session.role == .windowExternalDisplayNonInteractive }
        for (index, scene) in externalScenes.enumerated() {
            displays.append(DisplayInfo(id: "ext-\(index)", name: "AirPlay Display \(index + 1)",  size: scene.coordinateSpace.bounds.size))
        }
        ExternalDisplayManager.availableDisplays = displays
#endif
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
