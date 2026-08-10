//
//  WindowCommands.swift
//  Front Row
//
//  Created by Joshua Park on 3/18/24.
//

import SwiftUI

struct WindowCommands: Commands {
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
                InspectorMenuItem()
            }
        }
    }
}

/// Shows or hides the Inspector.
///
/// Written out rather than left to the one SwiftUI generates for the scene, which names itself
/// after the window and can't be placed, labelled, or enabled from here.
private struct InspectorMenuItem: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    private var presentation = InspectorPresentation.shared

    var body: some View {
        Button {
            if presentation.isOpen {
                dismissWindow(id: WindowID.inspector)
            } else {
                openWindow(id: WindowID.inspector)
            }
        } label: {
            if presentation.isOpen {
                Text("Hide Inspector", comment: "Closes the media Inspector window")
            } else {
                Text("Show Inspector", comment: "Opens the media Inspector window")
            }
        }
        .keyboardShortcut("i", modifiers: [.command])
    }
}
