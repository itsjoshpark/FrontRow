//
//  SkipButton.swift
//  Front Row
//
//  Created by Joshua Park on 8/5/26.
//

import SwiftUI

/// Skips playback by the current skip interval. The symbol states the interval, so the button
/// relabels itself whenever that setting changes.
struct SkipButton: View {
    enum Direction {
        case backward
        case forward

        var shortcut: KeyEquivalent {
            switch self {
            case .backward: "J"
            case .forward: "L"
            }
        }

        var accessibilityIdentifier: String {
            switch self {
            case .backward: "skip-backward"
            case .forward: "skip-forward"
            }
        }
    }

    let direction: Direction

    @Environment(PlayEngine.self) private var playEngine: PlayEngine

    var body: some View {
        Button {
            Task {
                switch direction {
                case .backward: await playEngine.goBackwards()
                case .forward: await playEngine.goForwards()
                }
            }
        } label: {
            Image(systemName: symbolName)
                .resizable()
                .scaledToFit()
                .foregroundStyle(PlayerControlColor.foreground)
                .frame(height: 20)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(direction.shortcut, modifiers: [])
        .focusable(false)
        .disabled(!playEngine.isLoaded)
        .accessibilityIdentifier(direction.accessibilityIdentifier)
    }

    private var symbolName: String {
        switch direction {
        case .backward: playEngine.skipInterval.backwardSymbol
        case .forward: playEngine.skipInterval.forwardSymbol
        }
    }
}
