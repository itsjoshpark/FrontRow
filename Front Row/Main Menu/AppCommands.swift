//
//  AppCommands.swift
//  Front Row
//
//  Created by Joshua Park on 3/11/24.
//

import Sparkle
import SwiftUI

struct AppCommands: Commands {

    nonisolated static let spatialAudioSampleURL = URL(
        string: "https://media.developer.dolby.com/DDP/MP4_HPL40_30fps_channel_id_51.mp4")!

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
                        // The route a recent file takes: the player window on success, the
                        // unopenable-file alert on failure. The sample is not in recents when
                        // that happens, so the alert's clean-up finds nothing to remove.
                        await openRecentDocument(url: Self.spatialAudioSampleURL)
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
