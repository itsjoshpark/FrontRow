//
//  PlaybackCommands.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import AVKit
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

            Menu {
                Button {
                    playEngine.playbackSpeed += 0.05
                } label: {
                    Text(
                        "Increase by 5%",
                        comment: "Increase playback speed by 5%"
                    )
                }
                .keyboardShortcut("]", modifiers: [.command])
                .disabled(!playEngine.isLoaded)

                Button {
                    playEngine.playbackSpeed -= 0.05
                } label: {
                    Text(
                        "Decrease by 5%",
                        comment: "Decrease playback speed by 5%"
                    )
                }
                .keyboardShortcut("[", modifiers: [.command])
                .disabled(!playEngine.isLoaded)

                Divider()

                Button {
                    playEngine.playbackSpeed = 1.0
                } label: {
                    Text(
                        "Reset",
                        comment: "Reset playback speed to 100%"
                    )
                }
                .keyboardShortcut("/", modifiers: [.command])
                .disabled(!playEngine.isLoaded)
            } label: {
                Text(
                    "Speed",
                    comment: "Playback speed"
                )
            }

            Divider()

            Picker(selection: $playEngine.skipInterval) {
                ForEach(PlayEngine.skipIntervals, id: \.self) { interval in
                    Text(
                        "\(interval)s",
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
                Text("Go Forward \(playEngine.skipInterval)s")
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            .disabled(!playEngine.isLoaded || presentedViewManager.isPresenting)

            Button {
                Task { await playEngine.goBackwards() }
            } label: {
                Text("Go Backward \(playEngine.skipInterval)s")
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            .disabled(!playEngine.isLoaded || presentedViewManager.isPresenting)

            Button {
                PresentedViewManager.shared.isPresentingGoToTimeView.toggle()
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

            audioTrackPicker

            Toggle(isOn: $playEngine.isMuted) {
                Text("Mute")
            }
            .keyboardShortcut("M", modifiers: [])
        }
    }

    @ViewBuilder private var audioTrackPicker: some View {
        if let group = playEngine.audioGroup {
            Picker("Audio Track", selection: $playEngine.audioTrack) {
                Text("Off").tag(nil as AVMediaSelectionOption?)
                ForEach(group.options, id: \.stableID) { option in
                    Text(verbatim: option.displayName).tag(Optional(option))
                }
            }
        } else {
            Picker("Audio Track", selection: .constant(0)) {
                Text("None").tag(0)
            }
            .disabled(true)
        }
    }
}
