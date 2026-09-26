//
//  FileCommands.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import AVKit
import SwiftUI

struct FileCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    private let playEngine = PlayEngine.shared
    private let presentationModel = PresentationModel.shared
    private let recentDocumentsStore = RecentDocumentsStore.shared

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
                presentationModel.isPresentingOpenURLView.toggle()
            } label: {
                Text(
                    "Open URL...",
                    comment: "Show the open URL dialog"
                )
            }
            .keyboardShortcut("O", modifiers: [.command, .shift])

            Menu {
                ForEach(recentDocumentsStore.recentURLs, id: \.self) { url in
                    Button {
                        Task {
                            await openRecentDocument(url: url)
                        }
                    } label: {
                        Label {
                            Text(url.lastPathComponent)
                        } icon: {
                            Image(nsImage: url.recentDocumentIcon)
                        }
                    }
                }

                if !recentDocumentsStore.recentURLs.isEmpty {
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
                .disabled(recentDocumentsStore.recentURLs.isEmpty)
            } label: {
                Text(
                    "Open Recent",
                    comment: "Title of the Open Recent submenu"
                )
            }

            Divider()

            Button {
                guard let item = playEngine.player.currentItem,
                    let asset = item.asset as? AVURLAsset
                else { return }
                NSWorkspace.shared.activateFileViewerSelecting([asset.url])
            } label: {
                Text(
                    "Show in Finder",
                    comment: "Show the currently playing file in Finder"
                )
            }
            .disabled(!playEngine.isLocalFile)

            Divider()

            Button {
                guard let url = playEngine.fileURL else { return }
                FileRemover().remove(
                    url, .trash, openWindow: openWindow, dismissWindow: dismissWindow)
            } label: {
                Text(
                    "Move to Trash",
                    comment: "Move the currently playing file to the Trash"
                )
            }
            .modifierKeyAlternate(.option) {
                Button {
                    guard let url = playEngine.fileURL else { return }
                    presentationModel.raise(.confirmDeletion(url))
                } label: {
                    Text(
                        "Delete Immediately...",
                        comment: "Delete the currently playing file without moving it to the Trash"
                    )
                }
                .disabled(!playEngine.isLocalFile || presentationModel.isPresenting)
            }
            .disabled(!playEngine.isLocalFile || presentationModel.isPresenting)
        }
    }
}
