import SwiftUI

/// Single source of truth for all view-toggle and action commands.
/// Each case defines its label, keyboard shortcut, and the ScopeState property it controls.
enum ScopeCommand: CaseIterable, Identifiable {
    case showControls
    case showSourceImage
    case showOutlines
    case flipAlternates
    case drawWithReflection
    case animate
    case reverseAnimation
    case advanceAnimation

    var id: Self { self }

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
        }
    }

    var isToggle: Bool {
        switch self {
        case .reverseAnimation, .advanceAnimation: return false
        default: return true
        }
    }

    /// KeyPath on ScopeState for toggle commands. Nil for non-toggles.
    var keyPath: ReferenceWritableKeyPath<ScopeState, Bool>? {
        switch self {
        case .showControls:       return \.showControls
        case .showSourceImage:    return \.showSourceImage
        case .showOutlines:       return \.showOutlines
        case .flipAlternates:     return \.flipAlternates
        case .drawWithReflection: return \.drawWithReflection
        case .animate:            return \.animate
        case .reverseAnimation, .advanceAnimation:   return nil
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
            guard flags == .option,
                  let chars = event.charactersIgnoringModifiers else { return false }
            switch self {
            case .showControls:       return chars == "c"
            case .showSourceImage:    return chars == "i"
            case .showOutlines:       return chars == "o"
            case .flipAlternates:     return chars == "f"
            case .drawWithReflection: return chars == "r"
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
