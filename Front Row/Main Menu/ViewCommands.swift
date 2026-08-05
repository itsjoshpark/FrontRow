//
//  ViewCommands.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import SwiftUI

struct ViewCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .toolbar) {
            Button {
                NSApplication.shared.mainWindow?.toggleFullScreen(nil)
            } label: {
                Text(
                    WindowController.shared.isFullscreen
                        ? "Exit Full Screen" : "Enter Full Screen")
            }
            .keyboardShortcut(.return, modifiers: [])

            Toggle(isOn: Bindable(WindowController.shared).isOnTop) {
                Text("Float on Top")
            }

            Divider()

            SubtitlePicker(playEngine: PlayEngine.shared)
        }
    }
}
