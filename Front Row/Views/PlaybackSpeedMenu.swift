//
//  PlaybackSpeedMenu.swift
//  Front Row
//
//  Created by Joshua Park on 8/5/26.
//

import SwiftUI

/// One of the three playback-speed actions, shared by the menu bar and the controls bar so the
/// two can't drift on what each one does. Keyboard shortcuts stay with the caller, since only the
/// menu bar owns those.
struct PlaybackSpeedButton: View {
    enum Action {
        case increase
        case decrease
        case reset
    }

    let action: Action
    let playEngine: PlayEngine

    var body: some View {
        Button(action: apply) {
            switch action {
            case .increase:
                Text(
                    "Increase by 5%",
                    comment: "Increase playback speed by 5%"
                )
            case .decrease:
                Text(
                    "Decrease by 5%",
                    comment: "Decrease playback speed by 5%"
                )
            case .reset:
                Text(
                    "Reset",
                    comment: "Reset playback speed to 100%"
                )
            }
        }
    }

    private func apply() {
        switch action {
        case .increase: playEngine.playbackSpeed += 0.05
        case .decrease: playEngine.playbackSpeed -= 0.05
        case .reset: playEngine.playbackSpeed = 1.0
        }
    }
}

/// The Playback ▸ Speed submenu.
struct PlaybackSpeedMenu: View {
    let playEngine: PlayEngine

    var body: some View {
        Menu {
            PlaybackSpeedButton(action: .increase, playEngine: playEngine)
                .keyboardShortcut("]", modifiers: [.command])
                .disabled(!playEngine.isLoaded)

            PlaybackSpeedButton(action: .decrease, playEngine: playEngine)
                .keyboardShortcut("[", modifiers: [.command])
                .disabled(!playEngine.isLoaded)

            Divider()

            PlaybackSpeedButton(action: .reset, playEngine: playEngine)
                .keyboardShortcut("/", modifiers: [.command])
                .disabled(!playEngine.isLoaded)
        } label: {
            Text(
                "Speed",
                comment: "Playback speed"
            )
        }
    }
}

/// Shows the current speed in the controls bar, and offers the same adjustments as the menu bar.
/// Hidden at normal speed, where there is nothing to report.
struct PlaybackSpeedIndicator: View {
    let playEngine: PlayEngine

    var body: some View {
        if !PlaybackSpeed.isDefault(playEngine.playbackSpeed) {
            Menu {
                Text("Speed")
                    .font(.system(size: 11).weight(.semibold))

                PlaybackSpeedButton(action: .increase, playEngine: playEngine)
                PlaybackSpeedButton(action: .decrease, playEngine: playEngine)
                PlaybackSpeedButton(action: .reset, playEngine: playEngine)
            } label: {
                Text(verbatim: formattedSpeed)
                    .font(.system(size: 11))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 50)
        }
    }

    private var formattedSpeed: String {
        let speed = playEngine.playbackSpeed.formatted(.number.precision(.fractionLength(2)))
        return "\(speed)×"
    }
}
