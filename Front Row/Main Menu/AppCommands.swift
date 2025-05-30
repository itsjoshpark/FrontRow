//
//  AppCommands.swift
//  Front Row
//
//  Created by Joshua Park on 3/11/24.
//

import Sparkle
import SwiftUI

struct AppCommands: Commands {
    private let updater: SPUUpdater

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button {
                updater.checkForUpdates()
            } label: {
                Text("Check for Updates…")
            }
            .disabled(!updater.canCheckForUpdates)

            Section {
                Button {
                    Task {
                        guard
                            let url = URL(
                                string:
                                    "https://media.developer.dolby.com/DDP/MP4_HPL40_30fps_channel_id_51.mp4"
                            )
                        else { return }
                        await PlayEngine.shared.openFile(url: url)
                    }
                } label: {
                    Text("Experience Spatial Audio")
                }
            }
        }
    }

    init(updater: SPUUpdater) {
        self.updater = updater
    }
}
