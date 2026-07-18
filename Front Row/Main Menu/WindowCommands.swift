//
//  WindowCommands.swift
//  Front Row
//
//  Created by Joshua Park on 3/18/24.
//

import SwiftUI

struct WindowCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .windowSize) {
            Section {
                Button {
                    PlayEngine.shared.fitToVideoSize()
                } label: {
                    Text(
                        "Natural Size",
                        comment: "Fit window to video size"
                    )
                }
                .keyboardShortcut("0", modifiers: [.command])
                .disabled(!PlayEngine.shared.isLoaded || WindowController.shared.isFullscreen)
            }
        }
    }
}
