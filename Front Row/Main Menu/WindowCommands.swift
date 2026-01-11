//
//  WindowCommands.swift
//  Front Row
//
//  Created by Joshua Park on 3/18/24.
//

import SwiftUI

struct WindowCommands: Commands {
    @Environment(PlayEngine.self) private var playEngine
    @Environment(WindowController.self) private var windowController

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
        }
    }
}
