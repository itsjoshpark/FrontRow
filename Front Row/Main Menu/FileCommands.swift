//
//  FileCommands.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import AVKit
import SwiftUI

struct FileCommands: Commands {
    @Binding var playEngine: PlayEngine

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button {
                Task { await PlayEngine.shared.showOpenFileDialog() }
            } label: {
                Text(
                    "Open File...",
                    comment: "Show the open file dialog"
                )
            }
            .keyboardShortcut("O", modifiers: [.command])

            Button {
                PresentedViewManager.shared.isPresentingOpenURLView.toggle()
            } label: {
                Text(
                    "Open URL...",
                    comment: "Show the open URL dialog"
                )
            }
            .keyboardShortcut("O", modifiers: [.command, .shift])

            Divider()

            Button {
                guard let item = PlayEngine.shared.player.currentItem else { return }
                guard let asset = item.asset as? AVURLAsset else { return }
                NSWorkspace.shared.activateFileViewerSelecting([asset.url])
            } label: {
                Text(
                    "Show in Finder",
                    comment: "Show the currently playing file in Finder"
                )
            }
            .disabled(!playEngine.isLocalFile)
        }
    }
}
