//
//  ViewCommands.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import SwiftUI

struct ViewCommands: Commands {
    private let playEngine = PlayEngine.shared
    @Bindable private var windowController = WindowController.shared

    var body: some Commands {
        CommandGroup(replacing: .toolbar) {
            Button {
                NSApplication.shared.mainWindow?.toggleFullScreen(nil)
            } label: {
                Text(
                    windowController.isFullscreen
                        ? "Exit Full Screen" : "Enter Full Screen")
            }
            .keyboardShortcut(.return, modifiers: [])

            Toggle(isOn: $windowController.isOnTop) {
                Text("Float on Top")
            }

            Divider()

            SubtitlePicker(playEngine: playEngine)
        }
    }
}
