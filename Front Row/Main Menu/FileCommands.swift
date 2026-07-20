//
//  FileCommands.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import AVKit
import SwiftUI

struct FileCommands: Commands {

    @State private var recentDocumentsStore = RecentDocumentsStore.shared

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
                ForEach(recentDocumentsStore.documents) { document in
                    Button {
                        Task {
                            await openRecentDocumentAndPresent(id: document.id)
                        }
                    } label: {
                        Label {
                            Text(document.url.lastPathComponent)
                        } icon: {
                            Image(nsImage: document.url.recentDocumentIcon)
                        }
                    }
                }

                if !recentDocumentsStore.documents.isEmpty {
                    Divider()
                }

                Button {
                    recentDocumentsStore.clear()
                } label: {
                    Text(
                        "Clear Menu",
                        comment: "Clears the Open Recent menu's list of recently opened files"
                    )
                }
                .disabled(recentDocumentsStore.documents.isEmpty)
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
