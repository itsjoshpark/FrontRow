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
                    let unavailableVolumeName = RecentDocumentsStore.shared.unavailableVolumeName(
                        for: url)

                    Button {
                        Task {
                            await openRecentDocumentAndPresent(url: url)
                        }
                    } label: {
                        Label {
                            Text(url.lastPathComponent)
                        } icon: {
                            // Menu items can't be dimmed without disabling them, so a disconnected
                            // file is flagged by swapping its icon instead. It stays clickable: the
                            // resulting alert is what explains the problem.
                            if unavailableVolumeName == nil {
                                Image(nsImage: url.recentDocumentIcon)
                            } else {
                                Image(systemName: "externaldrive.badge.xmark")
                            }
                        }
                    }
                    .help(
                        unavailableVolumeName.map {
                            String(
                                localized: "On \"\($0)\", which isn't connected",
                                comment:
                                    "Tooltip for an Open Recent menu item whose drive is not mounted"
                            )
                        } ?? ""
                    )
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
