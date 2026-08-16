//
//  PlayerControlsView.swift
//  Front Row
//
//  Created by Joshua Park on 3/25/24.
//

import SwiftUI

struct PlayerControlsView: View {
    @Environment(PlayEngine.self) private var playEngine: PlayEngine

    var body: some View {
        @Bindable var playEngine = playEngine

        HStack(spacing: 8) {
            HStack(spacing: 16) {
                SkipButton(direction: .backward)
                PlayPauseButton()
                SkipButton(direction: .forward)
            }
            CurrentTimeLabel()
            SeekSliderView(value: $playEngine.currentTime, maxValue: playEngine.duration)
                .focusable(false)
                .disabled(!playEngine.isLoaded)
            DurationLabel()
            PlaybackSpeedIndicator(playEngine: playEngine)
            if playEngine.subtitleGroup != nil {
                Menu {
                    SubtitlePicker(playEngine: playEngine)
                } label: {
                    Image(systemName: "captions.bubble")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 40)
            }
        }
        .padding([.horizontal], 16)
        .padding([.vertical], 8)
        .background(.ultraThickMaterial)
    }
}

private struct CurrentTimeLabel: View {
    @Environment(PlayEngine.self) private var playEngine: PlayEngine

    var body: some View {
        Text(verbatim: playEngine.currentTime.asTimecode(using: playEngine.duration))
            .font(.system(size: 11))
            .foregroundStyle(PlayerControlColor.text(isEnabled: playEngine.isLoaded))
            .frame(minWidth: 50, alignment: .center)
    }
}

/// Shows the file's length, or how much of it is left. Clicking swaps between the two.
private struct DurationLabel: View {
    @Environment(PlayEngine.self) private var playEngine: PlayEngine
    @AppStorage("ShowTimeRemaining") private var showTimeRemaining = true

    var body: some View {
        Text(
            verbatim: showTimeRemaining
                ? "-\(playEngine.timeRemaining.asTimecode(using: playEngine.duration))"
                : playEngine.duration.asTimecode(using: playEngine.duration)
        )
        .font(.system(size: 11))
        .foregroundStyle(PlayerControlColor.text(isEnabled: playEngine.isLoaded))
        .frame(minWidth: 50, alignment: .center)
        .onHover { inside in
            if inside {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onTapGesture {
            showTimeRemaining.toggle()
        }
    }
}

#Preview {
    PlayerControlsView()
        .environment(PlayEngine.shared)
        .environment(PresentedViewManager.shared)
        .environment(WindowController.shared)
}
