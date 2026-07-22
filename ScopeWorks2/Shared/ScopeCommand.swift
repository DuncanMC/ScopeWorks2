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
        case .reverseAnimation:   return "Reverse Animation"
        case .advanceAnimation:   return "Advance animation 1 frame"
        case .showCropRect:       return "Show crop rectangle"
        case .showFullscreenView: return "Show Full-screen Kaleidoscope"
        case .selectNextFullScreenDisplay:
                                  return "Select next full-screen display"
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

        }
    }

    var isToggle: Bool {
        switch self {
        case .reverseAnimation,
                .advanceAnimation,
                .selectNextFullScreenDisplay:
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
        case .animate:              return \.animate
        case
                .reverseAnimation,
                .advanceAnimation,
                .selectNextFullScreenDisplay:
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
            //print("Advance animation menu item chosen")
            state.animateByElapsed( 1.0 / 120.0)
        case .reverseAnimation:
            state.rotationSpeed *= -1
            state.movementSpeed *= -1
        case .selectNextFullScreenDisplay:
            state.selectNextFullScreenDisplay()
        default:
            if let kp = keyPath {
                state[keyPath: kp].toggle()
            }
        }
    }

    static let viewCommands: [ScopeCommand] = ScopeCommand.allCases

    // MARK: - NSEvent matching (macOS full-screen window)

#if os(macOS)
    /// Returns true if the given NSEvent matches this command's shortcut.
    func matches(event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch self {
        case .animate:
            return event.keyCode == 36 && flags.isEmpty
        case .reverseAnimation:
            return flags == .command && event.charactersIgnoringModifiers == "r"
        case .advanceAnimation: 
            let chars = event.charactersIgnoringModifiers
            return chars == "a" && flags == [.option, .command]
        default:
            guard let chars = event.charactersIgnoringModifiers else { return false }
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

    var body: some View {
        VStack {
            ForEach(ScopeCommand.viewCommands) { command in
                if command.isToggle, let kp = command.keyPath {
                    Toggle(command.label, isOn: Binding(
                        get: { scopeState[keyPath: kp] },
                        set: { scopeState[keyPath: kp] = $0 }
                    ))
                    .keyboardShortcut(command.shortcutKey, modifiers: command.shortcutModifiers)
                } else {
                    Button(command.label) {
                        command.performAction(on: scopeState)
                    }
                    .keyboardShortcut(command.shortcutKey, modifiers: command.shortcutModifiers)
                }
            }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }
}
