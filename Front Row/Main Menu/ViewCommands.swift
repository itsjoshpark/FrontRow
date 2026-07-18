//
//  ViewCommands.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import AVKit
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

            subtitlePicker
        }
    }

    @ViewBuilder private var subtitlePicker: some View {
        if let group = PlayEngine.shared.subtitleGroup {
            Picker("Subtitle", selection: Bindable(PlayEngine.shared).subtitle) {
                Text("Off").tag(nil as AVMediaSelectionOption?)

                let optionsWithoutForcedSubs = group.options.filter {
                    !$0.displayName.contains("Forced")
                }
                ForEach(optionsWithoutForcedSubs, id: \.stableID) {
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
