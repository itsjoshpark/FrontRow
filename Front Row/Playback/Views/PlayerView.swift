//
//  PlayerView.swift
//  Front Row
//
//  Created by Joshua Park on 3/25/24.
//

import AVFoundation
import SwiftUI

struct PlayerView: NSViewRepresentable {
    let player: AVPlayer

    class PlayerNSView: NSView, CALayerDelegate {

        private let playerLayer = AVPlayerLayer()

        override func makeBackingLayer() -> CALayer {
            playerLayer
        }

        /// The drag is performed in `mouseDown` instead, so AppKit must not take the click for
        /// `isMovableByWindowBackground` before this view sees it.
        override var mouseDownCanMoveWindow: Bool { false }

        override func mouseDown(with event: NSEvent) {
            guard let window else {
                super.mouseDown(with: event)
                return
            }

            switch PlayerClickAction(
                clickCount: event.clickCount,
                isFullscreen: window.styleMask.contains(.fullScreen)
            ) {
            case .moveWindow: window.performDrag(with: event)
            case .toggleFullScreen: window.toggleFullScreen(nil)
            case .ignore: super.mouseDown(with: event)
            }
        }

        override func rightMouseUp(with event: NSEvent) {
            // The shared engine rather than an injected one: this is an AppKit event handler, with
            // no SwiftUI environment to read from.
            PlayEngine.shared.playPause()
            super.rightMouseUp(with: event)
        }

        init(player: AVPlayer) {
            super.init(frame: .zero)
            playerLayer.player = player
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    func makeNSView(context: Context) -> some NSView {
        return PlayerNSView(player: player)
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {
    }
}
