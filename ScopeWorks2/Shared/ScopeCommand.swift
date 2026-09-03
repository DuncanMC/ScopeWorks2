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
    case moveUp
    case moveUp10
    case moveDown
    case moveDown10
    case moveLeft
    case moveLeft10
    case moveRight
    case moveRight10

    var id: Self { self }
    
    var isEditMenuCommand: Bool {
        switch self {
        case .moveUp, .moveDown, .moveLeft, .moveRight, .moveUp10, .moveDown10, .moveLeft10, .moveRight10:
            return true
        default:
            return false
        }
    }

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
        case .moveUp:             return "Up"
        case .moveDown:           return "Down"
        case .moveLeft:           return "Left"
        case .moveRight:          return "Right"
        case .moveUp10:             return "Up 10 pixels"
        case .moveDown10:           return "Down 10 pixels"
        case .moveLeft10:           return "Left 10 pixels"
        case .moveRight10:          return "Right 10 pixels"
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
                .flipAlternates,
                .moveUp,
                .moveDown,
                .moveLeft,
                .moveRight,
                .moveUp10,
                .moveDown10,
                .moveLeft10,
                .moveRight10:
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
        case .moveUp, .moveUp10:
            return .upArrow
        case .moveDown, .moveDown10:
            return .downArrow
        case .moveLeft, .moveLeft10:
            return .leftArrow
        case .moveRight, .moveRight10:
            return .rightArrow
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
        // On iPadOS the system focus engine consumes unmodified arrow keys
        // for keyboard navigation before app shortcuts see them (and shift
        // alone is the only modifier it leaves free), so the nudge shortcuts
        // use ⌘-arrow / ⇧⌘-arrow there. macOS keeps plain and shifted arrows.
        case
                .moveUp,
                .moveDown,
                .moveLeft,
                .moveRight:
            return .command
        case
                .moveUp10,
                .moveDown10,
                .moveLeft10,
                .moveRight10:
            return [.shift, .command]
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
        // These hints are only displayed on iOS, where the nudge shortcuts
        // are ⌘-arrow / ⇧⌘-arrow. Real arrow glyphs are used because
        // KeyEquivalent.upArrow.character and friends are the non-printable
        // function-key code points (U+F700…), which don't render in titles.
        case .moveUp:             return "⌘↑"
        case .moveDown:           return "⌘↓"
        case .moveLeft:           return "⌘←"
        case .moveRight:          return "⌘→"
        case .moveUp10:             return "⇧⌘↑"
        case .moveDown10:           return "⇧⌘↓"
        case .moveLeft10:           return "⇧⌘←"
        case .moveRight10:          return "⇧⌘→"
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
                .moveRotationCenter,
                .moveUp,
                .moveDown,
                .moveLeft,
                .moveRight,
                .moveUp10,
                .moveDown10,
                .moveLeft10,
                .moveRight10:
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
            // xxx
            state.animateByElapsed( 1.0 / 60.0)
        case .reverseAnimation:
            state.rotationSpeed *= -1
            state.movementSpeed *= -1
        case .selectNextFullScreenDisplay:
            state.selectNextFullScreenDisplay()
        case .moveRotationCenter:
            state.moveRotationCenter()
        case .moveUp:
            state.handleArrowKey(self.shortcutKey, isShifted: false)

        case .moveDown:
            state.handleArrowKey(self.shortcutKey, isShifted: false)
        case .moveLeft:
            state.handleArrowKey(self.shortcutKey, isShifted: false)
        case .moveRight:
            state.handleArrowKey(self.shortcutKey, isShifted: false)
        case .moveUp10:
            state.handleArrowKey(self.shortcutKey, isShifted: true)
        case .moveDown10:
            state.handleArrowKey(self.shortcutKey, isShifted: true)
        case .moveLeft10:
            state.handleArrowKey(self.shortcutKey, isShifted: true)
        case .moveRight10:
            state.handleArrowKey(self.shortcutKey, isShifted: true)
        default:
            if let kp = keyPath {
                withAnimation {
                    state[keyPath: kp].toggle()
                }
            }
        }
    }

    static let viewCommands: [ScopeCommand] = ScopeCommand.allCases.filter { !$0.isEditMenuCommand}
    static let editCommands: [ScopeCommand] = ScopeCommand.allCases.filter { $0.isEditMenuCommand}

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
        case .moveUp:
            return event.keyCode == 126 && flags.isEmpty
        case .moveDown:
            return event.keyCode == 125 && flags.isEmpty
        case .moveLeft:
            return event.keyCode == 123 && flags.isEmpty
        case .moveRight:
            return event.keyCode == 124 && flags.isEmpty
        case .moveUp10:
            return event.keyCode == 126 && flags == [.shift]
        case .moveDown10:
            return event.keyCode == 125 && flags == [.shift]
        case .moveLeft10:
            return event.keyCode == 123 && flags == [.shift]
        case .moveRight10:
            return event.keyCode == 124 && flags == [.shift]
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

// MARK: - Shortcut registration helper

extension View {
    /// Applies the command's keyboard shortcut.
    func keyboardShortcut(for command: ScopeCommand) -> some View {
        self.keyboardShortcut(command.shortcutKey, modifiers: command.shortcutModifiers)
    }
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
            ForEach(ScopeCommand.viewCommands + ScopeCommand.editCommands) { command in
                
                if !alternateShortcutCommandsOnly {
                    if command.isToggle, let kp = command.keyPath {
                        Toggle(command.label, isOn: toggleBinding(for: kp))
                            .disabled(command.disableCommandClosure(scopeState))
                            .keyboardShortcut(for: command)
                        // A second hidden control for commands with an alternate key
                        // (e.g. Enter also toggles animation, in addition to Return).
                        if let altKey = command.alternateShortcutKey {
                            Toggle(command.label, isOn: toggleBinding(for: kp))
                                .disabled(command.disableCommandClosure(scopeState))
                                .keyboardShortcut(altKey, modifiers: command.alternateShortcutModifiers)
                        }
                    } else {
                        Button(command.label) {
//                            print("Triggering button \(command.label) from ScopeCommandButtons")
                            command.performAction(on: scopeState)
                        }
                        .disabled(command.disableCommandClosure(scopeState))
                        .keyboardShortcut(for: command)
                        if let altKey = command.alternateShortcutKey {
                            Button(command.label) {
//                                print("Triggering button \(command.label) from ScopeCommandButtons")
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
//                                print("Triggering button \(command.label) from ScopeCommandButtons")
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
