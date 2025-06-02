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
                Task {
                    await showOpenFileDialog()
                }
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

    private func showOpenFileDialog() async {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = PlayEngine.supportedFileTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        let resp = await panel.beginSheetModal(for: NSApplication.shared.mainWindow!)
        if resp != .OK {
            return
        }

        guard let url = panel.url else { return }
        await PlayEngine.shared.openFile(url: url)
    }
}
