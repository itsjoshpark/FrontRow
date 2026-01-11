//
//  ViewCommands.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import AVKit
import SwiftUI

struct ViewCommands: Commands {
    @Environment(PlayEngine.self) private var playEngine
    @Environment(WindowController.self) private var windowController

    var body: some Commands {
        @Bindable var playEngine = playEngine
        @Bindable var windowController = windowController

        CommandGroup(replacing: .toolbar) {
            Button {
                NSApplication.shared.mainWindow?.toggleFullScreen(nil)
            } label: {
                Text(windowController.isFullscreen ? "Exit Full Screen" : "Enter Full Screen")
            }
            .keyboardShortcut(.return, modifiers: [])

            Toggle(isOn: $windowController.isOnTop) {
                Text("Float on Top")
            }

            Divider()

            subtitlePicker(playEngine: $playEngine)
        }
    }

    @ViewBuilder private func subtitlePicker(playEngine: Bindable<PlayEngine>) -> some View {
        if let group = playEngine.wrappedValue.subtitleGroup {
            Picker("Subtitle", selection: playEngine.subtitle) {
                Text("Off").tag(nil as AVMediaSelectionOption?)

                let optionsWithoutForcedSubs = group.options.filter {
                    !$0.displayName.contains("Forced")
                }
                ForEach(optionsWithoutForcedSubs) {
                    option in
                    Text(verbatim: option.displayName).tag(Optional(option))
                }
            }
            .pickerStyle(.inline)
        } else {
            Picker("Subtitle", selection: .constant(0)) {
                Text("None").tag(0)
            }
            .pickerStyle(.inline)
            .disabled(true)
        }
    }
}
