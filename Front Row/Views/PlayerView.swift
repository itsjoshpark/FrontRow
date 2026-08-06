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

        override func mouseDown(with event: NSEvent) {
            if event.type == .leftMouseDown && event.clickCount == 2 {
                NSApplication.shared.mainWindow?.toggleFullScreen(nil)
            } else {
                super.mouseDown(with: event)
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
