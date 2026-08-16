//
//  PlayPauseButton.swift
//  Front Row
//
//  Created by Joshua Park on 8/5/26.
//

import SwiftUI

struct PlayPauseButton: View {
    @Environment(PlayEngine.self) private var playEngine: PlayEngine

    var body: some View {
        Button {
            playEngine.playPause()
        } label: {
            Image(
                systemName: playEngine.timeControlStatus == .playing
                    ? "pause.fill"
                    : "play.fill"
            )
            .resizable()
            .scaledToFit()
            .foregroundStyle(PlayerControlColor.foreground)
            .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("K", modifiers: [])
        .focusable(false)
        .disabled(!playEngine.isLoaded)
    }
}
