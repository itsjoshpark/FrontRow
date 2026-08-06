//
//  PlaybackCommands.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import SwiftUI

struct PlaybackCommands: Commands {
    @Bindable private var playEngine = PlayEngine.shared
    @Bindable private var presentedViewManager = PresentedViewManager.shared

    var body: some Commands {
        CommandMenu("Playback") {
            Button {
                playEngine.playPause()
            } label: {
                Text(
                    playEngine.timeControlStatus == .playing ? "Pause" : "Play",
                    comment: "Toggle playback status"
                )
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(!playEngine.isLoaded)

            Button {
                Task { await playEngine.goToTime(0.0) }
            } label: {
                Text(
                    "Restart",
                    comment: "Restart playback from the beginning"
                )
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command])
            .disabled(!playEngine.isLoaded || presentedViewManager.isPresenting)

            PlaybackSpeedMenu(playEngine: playEngine)

            Divider()

            Picker(selection: $playEngine.skipInterval) {
                ForEach(SkipInterval.allCases) { interval in
                    Text(
                        "\(interval.rawValue)s",
                        comment: "Label displaying seconds"
                    ).tag(interval)
                }
            } label: {
                Text(
                    "Skip Interval",
                    comment: "How many seconds to go forward or backward"
                )
            }

            Button {
                Task { await playEngine.goForwards() }
            } label: {
                Text("Go Forward \(playEngine.skipInterval.rawValue)s")
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            .disabled(!playEngine.isLoaded || presentedViewManager.isPresenting)

            Button {
                Task { await playEngine.goBackwards() }
            } label: {
                Text("Go Backward \(playEngine.skipInterval.rawValue)s")
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            .disabled(!playEngine.isLoaded || presentedViewManager.isPresenting)

            Button {
                presentedViewManager.isPresentingGoToTimeView.toggle()
            } label: {
                Text("Go to Time...")
            }
            .keyboardShortcut("G", modifiers: [.command])
            .disabled(!playEngine.isLoaded)

            Divider()

            Button {
                playEngine.frameStep(1)
            } label: {
                Text("Next Frame")
            }
            .keyboardShortcut(".", modifiers: [])
            .disabled(!playEngine.isLoaded || presentedViewManager.isPresenting)

            Button {
                playEngine.frameStep(-1)
            } label: {
                Text("Previous Frame")
            }
            .keyboardShortcut(",", modifiers: [])
            .disabled(!playEngine.isLoaded || presentedViewManager.isPresenting)

            Divider()

            AudioTrackPicker(playEngine: playEngine)

            Toggle(isOn: $playEngine.isMuted) {
                Text("Mute")
            }
            .keyboardShortcut("M", modifiers: [])
        }
    }
}
