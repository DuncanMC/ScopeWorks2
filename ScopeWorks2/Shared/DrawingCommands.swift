//
//  DrawingCommands.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 7/1/26.
//  Copyright (c) 2026 Duncan Champney. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: macOS menubar
struct ScopeWorksCommands: Commands {
    @FocusedObject var scopeState: ScopeState?
    @Environment(\.openWindow) var open
    var body: some Commands {
        
        CommandGroup(before: .toolbar) {
            Toggle("Show controls", isOn:
                    Binding(
                        get: { scopeState?.showControls ?? false },
                        set: { newValue in scopeState?.showControls = newValue }
                    ))
            .keyboardShortcut("c", modifiers: .option)
            .disabled(scopeState == nil)

            Toggle("Show source image", isOn:
                    Binding(
                        get: { scopeState?.showSourceImage ?? false },
                        set: { newValue in scopeState?.showSourceImage = newValue }
                    ))
            .keyboardShortcut("i", modifiers: .option)
            .disabled(scopeState == nil)
            Toggle("Show outlines", isOn:
                    Binding(
                        get: { scopeState?.showOutlines ?? false },
                        set: { newValue in scopeState?.showOutlines = newValue }
                    ))
            .keyboardShortcut("o", modifiers: .option)
            .disabled(scopeState == nil)
            /*
             Toggle("xxx", isOn:
                     Binding(
                         get: { scopeState?.xxx ?? false },
                         set: { newValue in scopeState?.xxx = newValue }
                     ))
             .keyboardShortcut("xxx", modifiers: .xxx)
             .disabled(scopeState == nil)

             */

            Toggle("Flip alternates", isOn:
                    Binding(
                        get: { scopeState?.flipAlternates ?? false },
                        set: { newValue in scopeState?.flipAlternates = newValue }
                    ))
            .keyboardShortcut("f", modifiers: .option)
            .disabled(scopeState == nil)

            Toggle("Draw with reflection", isOn:
                    Binding(
                        get: { scopeState?.drawWithReflection ?? false },
                        set: { newValue in scopeState?.drawWithReflection = newValue }
                    ))
            .keyboardShortcut("r", modifiers: .option)
            .disabled(scopeState == nil)

            //↩
            Toggle("Animate", isOn:
                    Binding(
                        get: { scopeState?.animate ?? false },
                        set: { newValue in scopeState?.animate = newValue }
                    ))
            .keyboardShortcut(.return, modifiers: [])
            .disabled(scopeState == nil)

//scopeState.animate
        }
    }
}
