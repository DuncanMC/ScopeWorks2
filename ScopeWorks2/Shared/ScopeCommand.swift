import SwiftUI

/// Single source of truth for all view-toggle and action commands.
/// Each case defines its label, keyboard shortcut, and the ScopeState property it controls.
enum ScopeCommand: CaseIterable, Identifiable, CustomStringConvertible {
    case showControls
    case showSourceImage
    case showOutlines
    case flipAlternates
    case drawWithReflection
    case animate
    case reverseAnimation
    case advanceAnimation
    case showCropRect
    case showFullscreenView
    case selectNextFullScreenDisplay
    case moveRotationCenter

    var id: Self { self }

    var description: String {
        return self.label
    }
    
    var label: String {
        switch self {
        case .showControls:       return "Show controls"
        case .showSourceImage:    return "Show source image"
        case .showOutlines:       return "Show outlines"
        case .flipAlternates:     return "Flip alternates"
        case .drawWithReflection: return "Draw with reflection"
        case .animate:            return "Animate"
        case .reverseAnimation:   return "Reverse animation"
        case .advanceAnimation:   return "Advance animation 1 frame"
        case .showCropRect:       return "Show crop rectangle"
        case .showFullscreenView: return "Show full-screen Kaleidoscope"
        case .selectNextFullScreenDisplay:
                                  return "Select next full-screen display"
        case .moveRotationCenter: return "Move rotation center to triangle center"
        }
    }

    var disableCommandClosure: ((ScopeState?) -> Bool) {
        switch self {
        case .showControls,
                .showSourceImage,
                .showOutlines,
                .drawWithReflection,
                .animate,
                .reverseAnimation,
                .advanceAnimation,
                .showCropRect,
                .showFullscreenView,
                .moveRotationCenter,
                .flipAlternates:
            return { $0 == nil }
        case .selectNextFullScreenDisplay:
            return { scopeState in
                guard let scopeState else { return true }
                return scopeState.availableDisplays.count < 2
            }
        }
    }
    
    var shortcutKey: KeyEquivalent {
        switch self {
        case .showControls:       return "c"
        case .showSourceImage:    return "i"
        case .showOutlines:       return "o"
        case .flipAlternates:     return "f"
        case .drawWithReflection: return "r"
        case .animate:            return .return
        case .reverseAnimation:   return "r"
        case .advanceAnimation:   return "a"
        case .showCropRect:       return "c"
        case .showFullscreenView: return "f"
        case .selectNextFullScreenDisplay: 
                                    return "x"
        case .moveRotationCenter: return "m"
        }
    }

    /// Secondary key that also triggers this command, or nil if there is none.
    /// The Enter key (U+0003, the AppKit keypad-Enter key equivalent) also
    /// toggles animation, in addition to Return.
    var alternateShortcutKey: KeyEquivalent? {
        switch self {
        //Add the spacebar as an altenate key for the animate command.
        case .animate: return KeyEquivalent(Character(" "))
        default:       return nil
        }
    }
    
    var alternateShortcutModifiers: EventModifiers {
        switch self {
        case .animate: return []
        default:       return self.shortcutModifiers
        }
    }

    var shortcutModifiers: EventModifiers {
        switch self {
        case .showControls, .showSourceImage, .showOutlines,
             .flipAlternates, .drawWithReflection:
            return .option
        case .animate:
            return []
        case .reverseAnimation:
            return .command
        case .advanceAnimation:
            return [.command, .option]
        case .showCropRect:
            return .control
        case .showFullscreenView:
            return .control
        case .selectNextFullScreenDisplay:
            return .control
        case .moveRotationCenter:
            return .option
        }
    }

    /// Human-readable shortcut hint for iOS toolbar labels.
    var shortcutHint: String {
        switch self {
        case .showControls:       return "⌥C"
        case .showSourceImage:    return "⌥I"
        case .showOutlines:       return "⌥O"
        case .flipAlternates:     return "⌥F"
        case .drawWithReflection: return "⌥R"
        case .animate:            return "↩"
        case .reverseAnimation:   return "⌘R"
        case .advanceAnimation:   return "⌘⌥A"
        case .showCropRect:       return "^C"
        case .showFullscreenView: return "^F"
        case .selectNextFullScreenDisplay:
                                  return "^X"
        case .moveRotationCenter:
            return "⌥M"
            
        }
    }

    var isToggle: Bool {
        switch self {
        case .reverseAnimation,
                .advanceAnimation,
                .selectNextFullScreenDisplay,
                .moveRotationCenter:
            return false
        default: return true
        }
    }

    /// KeyPath on ScopeState for toggle commands. Nil for non-toggles.
    var keyPath: ReferenceWritableKeyPath<ScopeState, Bool>? {
        switch self {
        case .showControls:         return \.showControls
        case .showSourceImage:      return \.showSourceImage
        case .showOutlines:         return \.showOutlines
        case .flipAlternates:       return \.flipAlternates
        case .drawWithReflection:   return \.drawWithReflection
        case .animate:
            return \.animate
        case
                .reverseAnimation,
                .advanceAnimation,
                .selectNextFullScreenDisplay,
                .moveRotationCenter:
                                    return nil
        case .showCropRect:
                                    return \.showCropRect
        case .showFullscreenView:
                                    return \.showFullscreenView
        }
    }

    /// Execute this command on a ScopeState instance.
    func performAction(on state: ScopeState) {
        switch self {
        case .advanceAnimation:
            state.animateByElapsed( 1.0 / 60.0)
        case .reverseAnimation:
            state.rotationSpeed *= -1
            state.movementSpeed *= -1
        case .selectNextFullScreenDisplay:
            state.selectNextFullScreenDisplay()
        case .moveRotationCenter:
            state.moveRotationCenter()
        default:
            if let kp = keyPath {
                withAnimation {
                    state[keyPath: kp].toggle()
                }
            }
        }
    }

    static let viewCommands: [ScopeCommand] = ScopeCommand.allCases

    // MARK: - NSEvent matching (macOS full-screen window)

#if os(macOS)
    /// Returns true if the given NSEvent matches this command's shortcut.
    func matches(event: NSEvent) -> Bool {
        // Compare only against the real modifier keys. This ignores incidental
        // flags like .capsLock (set whenever caps lock is on) and .numericPad
        // (set by the keypad Enter key), which would otherwise break matching.
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        switch self {
        case .animate:
            // 36 = Return, 76 = keypad Enter, 32 = space
            return (event.keyCode == 36 || event.keyCode == 76 || event.keyCode == 49) && flags.isEmpty
        case .reverseAnimation:
            return flags == .command && event.charactersIgnoringModifiers?.lowercased() == "r"
        case .advanceAnimation:
            let chars = event.charactersIgnoringModifiers?.lowercased()
            return chars == "a" && flags == [.option, .command]
        default:
            // Lowercase because caps lock uppercases charactersIgnoringModifiers.
            guard let chars = event.charactersIgnoringModifiers?.lowercased() else { return false }
            switch (flags, self) {
            case (.option, .showControls):       return chars == "c"
            case (.option, .showSourceImage):    return chars == "i"
            case (.option, .showOutlines):       return chars == "o"
            case (.option, .flipAlternates):     return chars == "f"
            case (.option, .drawWithReflection): return chars == "r"
            case (.control, .showFullscreenView):
                return chars == "f"
            case (.control, .selectNextFullScreenDisplay):
                return chars == "x"
            default: return false
            }
        }
    }
#endif
}

// MARK: - Reusable hidden buttons view for iOS keyboard shortcuts

/// Renders all ScopeCommands as hidden SwiftUI controls with keyboard shortcuts.
/// Usage: `.background { ScopeCommandButtons(scopeState: scopeState) }`
struct ScopeCommandButtons: View {
    @ObservedObject var scopeState: ScopeState
    let alternateShortcutCommandsOnly: Bool

    private func toggleBinding(for kp: ReferenceWritableKeyPath<ScopeState, Bool>) -> Binding<Bool> {
        Binding(
            get: { scopeState[keyPath: kp] },
            set: { value in
                withAnimation {
                    scopeState[keyPath: kp] = value
                }
            }
        )
    }

    var body: some View {
        VStack {
            ForEach(ScopeCommand.viewCommands) { command in
                
                if !alternateShortcutCommandsOnly {
                    if command.isToggle, let kp = command.keyPath {
                        Toggle(command.label, isOn: toggleBinding(for: kp))
                            .disabled(command.disableCommandClosure(scopeState))
                            .keyboardShortcut(command.shortcutKey, modifiers: command.shortcutModifiers)
                        // A second hidden control for commands with an alternate key
                        // (e.g. Enter also toggles animation, in addition to Return).
                        if let altKey = command.alternateShortcutKey {
                            Toggle(command.label, isOn: toggleBinding(for: kp))
                                .disabled(command.disableCommandClosure(scopeState))
                                .keyboardShortcut(altKey, modifiers: command.alternateShortcutModifiers)
                        }
                    } else {
                        Button(command.label) {
                            command.performAction(on: scopeState)
                        }
                        .disabled(command.disableCommandClosure(scopeState))
                        .keyboardShortcut(command.shortcutKey, modifiers: command.shortcutModifiers)
                        if let altKey = command.alternateShortcutKey {
                            Button(command.label) {
                                command.performAction(on: scopeState)
                            }
                            .disabled(command.disableCommandClosure(scopeState))
                            .keyboardShortcut(altKey, modifiers: command.alternateShortcutModifiers)
                        }
                    }
                } else {
                    if let altKey = command.alternateShortcutKey {
                        if command.isToggle, let kp = command.keyPath {
                            Toggle(command.label, isOn: toggleBinding(for: kp))
                                .disabled(command.disableCommandClosure(scopeState))
                                .keyboardShortcut(altKey, modifiers: command.shortcutModifiers)
                        } else {
                            Button(command.label) {
                                command.performAction(on: scopeState)
                            }
                            .disabled(command.disableCommandClosure(scopeState))
                            .keyboardShortcut(altKey, modifiers: command.shortcutModifiers)
                        }
                    }

                }
            }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }
}
