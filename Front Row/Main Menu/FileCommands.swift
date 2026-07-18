//
//  FileCommands.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import AVKit
import SwiftUI

struct FileCommands: Commands {
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

            Menu {
                ForEach(RecentDocumentsStore.shared.recentURLs, id: \.self) { url in
                    Button {
                        Task {
                            await openRecentDocumentAndPresent(url: url)
                        }
                    } label: {
                        Label {
                            Text(url.lastPathComponent)
                        } icon: {
                            Image(nsImage: url.recentDocumentIcon)
                        }
                    }
                }

                if !RecentDocumentsStore.shared.recentURLs.isEmpty {
                    Divider()
                }

                Button {
                    RecentDocumentsStore.shared.clear()
                } label: {
                    Text(
                        "Clear Menu",
                        comment: "Clears the Open Recent menu's list of recently opened files"
                    )
                }
                .disabled(RecentDocumentsStore.shared.recentURLs.isEmpty)
            } label: {
                Text(
                    "Open Recent",
                    comment: "Title of the Open Recent submenu"
                )
            }

            Divider()

            Button {
                guard let item = PlayEngine.shared.player.currentItem,
                    let asset = item.asset as? AVURLAsset
                else { return }
                NSWorkspace.shared.activateFileViewerSelecting([asset.url])
            } label: {
                Text(
                    "Show in Finder",
                    comment: "Show the currently playing file in Finder"
                )
            }
            .disabled(!PlayEngine.shared.isLocalFile)
        }
    }

    @MainActor
    private func showOpenFileDialog() async {
        guard let url = await presentOpenFilePanel() else { return }
        await openFileAndPresent(url: url)
    }
}
