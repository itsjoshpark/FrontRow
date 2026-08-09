//
//  WindowCommands.swift
//  Front Row
//
//  Created by Joshua Park on 3/18/24.
//

import SwiftUI

struct WindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    private let playEngine = PlayEngine.shared
    private let windowController = WindowController.shared

    var body: some Commands {
        CommandGroup(after: .windowSize) {
            Section {
                Button {
                    playEngine.fitToVideoSize()
                } label: {
                    Text(
                        "Natural Size",
                        comment: "Fit window to video size"
                    )
                }
                .keyboardShortcut("0", modifiers: [.command])
                .disabled(!playEngine.isLoaded || windowController.isFullscreen)
            }

            Section {
                Button {
                    if windowController.isInspectorOpen {
                        dismissWindow(id: WindowID.inspector)
                        windowController.setIsInspectorOpen(false)
                    } else {
                        openWindow(id: WindowID.inspector)
                        windowController.setIsInspectorOpen(true)
                    }
                } label: {
                    if windowController.isInspectorOpen {
                        Text("Hide Inspector", comment: "Closes the media Inspector window")
                    } else {
                        Text("Show Inspector", comment: "Opens the media Inspector window")
                    }
                }
                .keyboardShortcut("i", modifiers: [.command])
            }
        }
    }
}
