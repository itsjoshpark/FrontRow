//
//  PlayerControlsView.swift
//  Front Row
//
//  Created by Joshua Park on 3/25/24.
//

import AVKit
import SwiftUI

struct PlayerControlsView: View {
    @Environment(PlayEngine.self) private var playEngine: PlayEngine
    @AppStorage("ShowTimeRemaining") var showTimeRemaining = true
    private let foregroundColor = Color.white.opacity(0.7)
    private let disabledControlTextColor = Color(nsColor: NSColor.disabledControlTextColor)

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 16) {
                backwards
                playPause
                forwards
            }
            currentTime
            seekSlider
            duration
            speedIndicator
            subtitlePicker
        }
        .padding([.horizontal], 16)
        .padding([.vertical], 8)
        .background(.ultraThickMaterial)
    }

    @ViewBuilder private var backwards: some View {
        @Bindable var playEngine = playEngine

        Button {
            Task { await PlayEngine.shared.goBackwards() }
        } label: {
            switch playEngine.skipInterval {
            case 5:
                Image(systemName: "gobackward.5")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(foregroundColor)
                    .frame(height: 20)
            case 10:
                Image(systemName: "gobackward.10")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(foregroundColor)
                    .frame(height: 20)
            case 15:
                Image(systemName: "gobackward.15")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(foregroundColor)
                    .frame(height: 20)
            case 30:
                Image(systemName: "gobackward.30")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(foregroundColor)
                    .frame(height: 20)
            default:
                Image(systemName: "gobackward")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(foregroundColor)
                    .frame(height: 20)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .keyboardShortcut("J", modifiers: [])
        .focusable(false)
        .disabled(!playEngine.isLoaded)
    }

    @ViewBuilder private var playPause: some View {
        @Bindable var playEngine = playEngine

        Button {
            PlayEngine.shared.playPause()
        } label: {
            Image(
                systemName: playEngine.timeControlStatus == .playing
                    ? "pause.fill"
                    : "play.fill"
            )
            .resizable()
            .scaledToFit()
            .foregroundStyle(foregroundColor)
            .frame(width: 24, height: 24)
        }
        .buttonStyle(PlainButtonStyle())
        .keyboardShortcut("K", modifiers: [])
        .focusable(false)
        .disabled(!playEngine.isLoaded)
    }

    @ViewBuilder private var forwards: some View {
        @Bindable var playEngine = playEngine

        Button {
            Task { await PlayEngine.shared.goForwards() }
        } label: {
            switch playEngine.skipInterval {
            case 5:
                Image(systemName: "goforward.5")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(foregroundColor)
                    .frame(height: 20)
            case 10:
                Image(systemName: "goforward.10")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(foregroundColor)
                    .frame(height: 20)
            case 15:
                Image(systemName: "goforward.15")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(foregroundColor)
                    .frame(height: 20)
            case 30:
                Image(systemName: "goforward.30")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(foregroundColor)
                    .frame(height: 20)
            default:
                Image(systemName: "goforward")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(foregroundColor)
                    .frame(height: 20)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .keyboardShortcut("L", modifiers: [])
        .focusable(false)
        .disabled(!playEngine.isLoaded)
    }

    @ViewBuilder private var currentTime: some View {
        @Bindable var playEngine = playEngine

        Text(verbatim: playEngine.currentTime.asTimecode(using: playEngine.duration))
            .font(.system(size: 11))
            .foregroundStyle(playEngine.isLoaded ? foregroundColor : disabledControlTextColor)
            .frame(minWidth: 50, alignment: .center)
    }

    @ViewBuilder private var seekSlider: some View {
        @Bindable var playEngine = playEngine

        SeekSliderView(value: $playEngine.currentTime, maxValue: playEngine.duration)
            .focusable(false)
            .disabled(!playEngine.isLoaded)
    }

    @ViewBuilder private var duration: some View {
        @Bindable var playEngine = playEngine

        Text(
            verbatim: showTimeRemaining
                ? "-\(playEngine.timeRemaining.asTimecode(using: playEngine.duration))"
                : playEngine.duration.asTimecode(using: playEngine.duration)
        )
        .font(.system(size: 11))
        .foregroundStyle(playEngine.isLoaded ? foregroundColor : disabledControlTextColor)
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

    @ViewBuilder private var speedIndicator: some View {
        @Bindable var playEngine = playEngine

        if !Float.isApproxEqual(lhs: playEngine.playbackSpeed, rhs: 1.0) {
            Menu {
                Text("Speed")
                    .font(.system(size: 11).weight(.semibold))

                Button {
                    playEngine.playbackSpeed += 0.05
                } label: {
                    Text(
                        "Increase by 5%",
                        comment: "Increase playback speed by 5%"
                    )
                }

                Button {
                    playEngine.playbackSpeed -= 0.05
                } label: {
                    Text(
                        "Decrease by 5%",
                        comment: "Decrease playback speed by 5%"
                    )
                }

                Button {
                    playEngine.playbackSpeed = 1.0
                } label: {
                    Text(
                        "Reset",
                        comment: "Reset playback speed to 100%"
                    )
                }
            } label: {
                Text(verbatim: String(format: "%.2f×", playEngine.playbackSpeed))
                    .font(.system(size: 11))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 50)
        }
    }

    @ViewBuilder private var subtitlePicker: some View {
        @Bindable var playEngine = playEngine

        if let group = playEngine.subtitleGroup {
            Menu {
                Picker("Subtitle", selection: $playEngine.subtitle) {
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
            } label: {
                Image(systemName: "captions.bubble")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 40)
        }
    }
}

#Preview {
    PlayerControlsView()
        .environment(PlayEngine.shared)
        .environment(PresentedViewManager.shared)
        .environment(WindowController.shared)
}
