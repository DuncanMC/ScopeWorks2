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
    var body: some Commands {
        
        CommandGroup(before: .saveItem) {
            Button("Save Image as") {
                scopeState?.saveImageAs()
            }
            .keyboardShortcut("s", modifiers: .option)
            .disabled(scopeState == nil)
            Button("Record Video") {
                scopeState?.recordVideo()
            }
            .disabled(scopeState == nil)
        }
        CommandGroup(before: .toolbar) {
            ForEach(ScopeCommand.viewCommands) { command in
                if command.isToggle, let kp = command.keyPath {
                    Toggle(command.label, isOn: Binding(
                        get: { scopeState?[keyPath: kp] ?? false },
                        set: { scopeState?[keyPath: kp] = $0 }
                    ))
                    .keyboardShortcut(command.shortcutKey, modifiers: command.shortcutModifiers)
                    .disabled(scopeState == nil)
                } else {
                    Button(command.label) {
                        guard let scopeState else { return }
                        command.performAction(on: scopeState)
                    }
                    .keyboardShortcut(command.shortcutKey, modifiers: command.shortcutModifiers)
                    .disabled(scopeState == nil)
                }
            }


            Divider()

            Button("Close External Display") {
                scopeState?.externalDisplayManager?.selectedDisplayID = nil
            }
            .keyboardShortcut(.escape, modifiers: [])
            .disabled(scopeState?.externalDisplayManager?.selectedDisplayID == nil)
        }
    }
}
