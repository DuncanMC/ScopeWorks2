//
//  ExternalDisplayManager.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 7/3/26.
//

import SwiftUI
import MetalKit
import Combine


#if os(macOS)
/// NSWindow subclass that accepts key events even when borderless.
class FullScreenPanel: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
#endif

/// Shared state between ExternalDisplayManager and FullScreenOverlayView
/// so the event monitor can trigger UI changes.
@MainActor
class FullScreenOverlayState: ObservableObject {
    @Published var showButton = true
    var exitAction: (() -> Void)?
    private var hideTask: Task<Void, Never>?

    func showExitButton() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showButton = true
        }
        scheduleHide()
    }

    func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                showButton = false
            }
        }
    }
}

/// Full-screen kaleidoscope with an "Exit Full Screen" button
/// that auto-hides after a delay and reappears on mouse movement / tap.
struct FullScreenOverlayView: View {
    @ObservedObject var scopeState: ScopeState
    @ObservedObject var overlayState: FullScreenOverlayState

    #if os(macOS)
        let exitFullscreenString = "Exit Full Screen (Esc)"
    #else
        let exitFullscreenString = "Exit Full Screen"
    #endif

    var body: some View {
        ZStack {
            #if os(iOS) || os(iPadOS)
                ScopeViewRepresentable(scopeState: scopeState,
                                       allowImageExport: true,
                                       isMainDocumentScopeView: false)
                .help("Tap with 2 fingers to take a snapshot")

                .gesture(TwoFingerTapGesture {
                    print("Two finger tap detected in full-screen view")
                    scopeState.handleSnapshot(isFullScreenView: true)
                })

                    .ignoresSafeArea()
            #else
                ScopeViewRepresentable(scopeState: scopeState,
                                       allowImageExport: true,
                                       isMainDocumentScopeView: false)
                    .ignoresSafeArea()
            #endif

            if overlayState.showButton {
                VStack {
                    VStack(spacing: 10) {
                        HStack {
                            Spacer()
                            Button {
                                overlayState.exitAction?()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white)
                                    Text(exitFullscreenString)
                                        .foregroundStyle(.white)
                                }
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .padding(20)
                        }
                        HStack {
                            Spacer()
                            Button {
                                scopeState.handleSnapshot(isFullScreenView: true)
                            } label: {
                                HStack(spacing: 6) {
                                    Text("Take Snapshot")
                                        .foregroundStyle(.white)
                                }
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .padding(20)

                        }
                    }
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            overlayState.scheduleHide()
        }
#if os(iOS)
        .onTapGesture {
            overlayState.showExitButton()
        }
        .background {
            ScopeCommandButtons(scopeState: scopeState)
        }
#endif
    }
}

@MainActor
class ExternalDisplayViewManager: NSObject, ObservableObject {

    
    @Published var selectedDisplayID: String? = nil {
        didSet {
            if selectedDisplayID != oldValue {
                updateExternalDisplay()
                if selectedDisplayID == nil {
                    Task { @MainActor in
                        scopeState?.showFullscreenView = false
                    }
                }
            }
        }
    }

    private weak var scopeState: ScopeState?
    private var overlayState: FullScreenOverlayState?

#if os(macOS)
    private var externalWindow: NSWindow?
    private var eventMonitor: Any?

#else
    private var externalWindow: UIWindow?
#endif

    init(scopeState: ScopeState) {
        self.scopeState = scopeState
        super.init()
        ExternalDisplayManager.shared.refreshDisplayList()

//        refreshDisplayList()
        setupNotifications()
#if os(iOS)
        ExternalDisplayBridge.shared.activeScopeState = scopeState
#endif
    }

    deinit {
#if os(macOS)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
#endif
    }

    // MARK: - Display List

//    func refreshDisplayList() {
//#if os(macOS)
//        availableDisplays = NSScreen.screens.compactMap { screen in
//            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
//                return nil
//            }
//            return DisplayInfo(id: String(screenNumber), name: screen.localizedName, size: screen.frame.size)
//            //Add height and width to this screen's displayInfo
//        }
//#else
//        var displays: [DisplayInfo] = []
//        // Always include the built-in screen
//        displays.append(DisplayInfo(id: "0", name: UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone", size: UIScreen.main.bounds.size))
//        // Add any external display scenes (AirPlay, HDMI, etc.)
//        let externalScenes = UIApplication.shared.connectedScenes
//            .compactMap { $0 as? UIWindowScene }
//            .filter { $0.session.role == .windowExternalDisplayNonInteractive }
//        for (index, scene) in externalScenes.enumerated() {
//            displays.append(DisplayInfo(id: "ext-\(index)", name: "AirPlay Display \(index + 1)",  size: scene.coordinateSpace.bounds.size))
//        }
//        availableDisplays = displays
//#endif
//
//        if let selectedID = selectedDisplayID,
//           !availableDisplays.contains(where: { $0.id == selectedID }) {
//            selectedDisplayID = nil
//        }
//    }

    // MARK: - Notifications

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: displaysChangedNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                let availableDisplays = ExternalDisplayManager.availableDisplays
                if let selectedID = self?.selectedDisplayID,
                   !availableDisplays.contains(where: { $0.id == selectedID }) {
                    self?.selectedDisplayID = nil
                }
            }
        }
    }

//#if os(macOS)
//        NotificationCenter.default.addObserver(
//            forName: NSApplication.didChangeScreenParametersNotification,
//            object: nil, queue: .main
//        ) { [weak self] _ in
//            MainActor.assumeIsolated {
//                self?.refreshDisplayList()
//            }
//        }
//#else
//        NotificationCenter.default.addObserver(
//            forName: UIScene.didActivateNotification,
//            object: nil, queue: .main
//        ) { [weak self] _ in
//            MainActor.assumeIsolated {
//                self?.refreshDisplayList()
//            }
//        }
//        NotificationCenter.default.addObserver(
//            forName: UIScene.didDisconnectNotification,
//            object: nil, queue: .main
//        ) { [weak self] _ in
//            MainActor.assumeIsolated {
//                self?.refreshDisplayList()
//            }
//        }
//#endif
//    }

    // MARK: - Window Management

    private func updateExternalDisplay() {
        closeExternalDisplay()
        guard let displayID = selectedDisplayID else { return }
        showOnDisplay(id: displayID)
    }

    func closeExternalDisplay() {
#if os(macOS)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        externalWindow?.delegate = nil
        externalWindow?.orderOut(nil)  // orderOut instead of close — avoids tearing down Metal mid-render
        externalWindow = nil
        overlayState = nil
#else
        externalWindow?.isHidden = true
        externalWindow = nil
        overlayState = nil
#endif
    }

    private func showOnDisplay(id: String) {
        guard let scopeState else { return }

#if os(macOS)
        guard let screen = NSScreen.screens.first(where: { screen in
            guard let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return false
            }
            return String(num) == id
        }) else { return }

        let state = FullScreenOverlayState()
        state.exitAction = { [weak self] in
            self?.selectedDisplayID = nil
            NotificationCenter.default.post(name: closingFullScreenNotification, object: scopeState)

        }
        overlayState = state

        let window = FullScreenPanel(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.acceptsMouseMovedEvents = true
        window.delegate = self
        window.contentView = NSHostingView(
            rootView: FullScreenOverlayView(scopeState: scopeState, overlayState: state)
        )
        window.setFrame(screen.frame, display: true)
        window.makeKeyAndOrderFront(nil)

        externalWindow = window

        // Monitor for keyboard shortcuts and mouse movement.
        // IMPORTANT: Never remove this monitor or close the window from within
        // this callback — defer via Task to avoid reentrancy crashes.
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .mouseMoved]) { [weak self] event in
            if event.type == .keyDown {
                // Escape key always closes the overlay
                if event.keyCode == 53 {
                    Task { @MainActor in
                        self?.selectedDisplayID = nil
                    }
                    return nil
                }

                // Handle menu shortcuts when the overlay window is key,
                // since it isn't part of a SwiftUI Scene and can't propagate
                // focusedSceneValue to the app's Commands.
                if event.window === self?.externalWindow {
                    for command in ScopeCommand.viewCommands {
                        if command.matches(event: event) {
                            Task { @MainActor in
                                if !command.disableCommandClosure(scopeState) {
                                    command.performAction(on: scopeState)
                                }
                            }
                            return nil
                        }
                    }
                }
            }

            if event.type == .mouseMoved, let window = self?.externalWindow {
                // Only show exit button when mouse is over the full-screen window
                let mouseLocation = NSEvent.mouseLocation
                if window.frame.contains(mouseLocation) {
                    Task { @MainActor in
                        self?.overlayState?.showExitButton()
                    }
                }
            }

            return event
        }
#else
        let state = FullScreenOverlayState()
        state.exitAction = { [weak self] in
            NotificationCenter.default.post(name: closingFullScreenNotification, object: scopeState)
            self?.selectedDisplayID = nil
        }
        overlayState = state

        let hostingController = UIHostingController(
            rootView: FullScreenOverlayView(scopeState: scopeState, overlayState: state)
        )
        hostingController.view.backgroundColor = .black

        // Find the appropriate window scene for this display
        let targetScene: UIWindowScene?
        if id == "0" {
            // Built-in screen: use the app's active window scene
            targetScene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
        } else if id.hasPrefix("ext-"), let index = Int(id.dropFirst(4)) {
            // External display scene (AirPlay, etc.)
            let externalScenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .filter { $0.session.role == .windowExternalDisplayNonInteractive }
            targetScene = index < externalScenes.count ? externalScenes[index] : nil
        } else {
            targetScene = nil
        }

        guard let scene = targetScene else { return }

        let window = UIWindow(windowScene: scene)
        window.windowLevel = .statusBar + 1
        window.rootViewController = hostingController
        window.makeKeyAndVisible()

        externalWindow = window
#endif
    }
}

#if os(macOS)
extension ExternalDisplayViewManager: NSWindowDelegate {
    nonisolated func windowWillClose(_ notification: Notification) {
        // Extract the window reference synchronously — NSNotification.object
        // does NOT retain its object, so deferring to Task would leave a dangling pointer.
        let closingWindow = notification.object as? NSWindow
        MainActor.assumeIsolated {
            guard closingWindow === externalWindow else { return }
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
            externalWindow = nil
            overlayState = nil
            selectedDisplayID = nil
        }
    }
}
#endif

// MARK: - iOS External Display Scene Support

#if os(iOS)
/// Static bridge so the external display scene delegate can access the active ScopeState.
@MainActor
class ExternalDisplayBridge {
    static let shared = ExternalDisplayBridge()
    weak var activeScopeState: ScopeState?
}

/// Scene delegate for external (AirPlay) displays.
/// iOS creates this automatically when an AirPlay device connects
/// and the app declares UIWindowSceneSessionRoleExternalDisplayNonInteractive.
class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        //print("In ExternalDisplaySceneDelegate.scene(_:willConnectTo:options:)")
        guard let windowScene = scene as? UIWindowScene else { return }

        Task { @MainActor in
            guard let scopeState = ExternalDisplayBridge.shared.activeScopeState else { return }

            let overlayState = FullScreenOverlayState()
            let hostingController = UIHostingController(
                rootView: FullScreenOverlayView(scopeState: scopeState, overlayState: overlayState)
            )
            hostingController.view.backgroundColor = .black

            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = hostingController
            window.makeKeyAndVisible()
            self.window = window

            // Refresh the display list so the picker shows the new screen
            ExternalDisplayManager.shared.refreshDisplayList()
            //scopeState.externalDisplayManager?.refreshDisplayList()
            scopeState.updateDisplays()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        window = nil
        Task { @MainActor in
            ExternalDisplayManager.shared.refreshDisplayList()
            guard let scopeState = ExternalDisplayBridge.shared.activeScopeState else { return }
            scopeState.updateDisplays()
        }
    }
}
#endif
