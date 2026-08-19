//
//  AppCommands.swift
//  Front Row
//
//  Created by Joshua Park on 3/11/24.
//

import Sparkle
import SwiftUI

struct AppCommands: Commands {

    /// A Dolby-hosted 5.1 clip, the app's own demonstration that multichannel audio reaches
    /// ordinary headphones.
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
                        // The route a recent file takes, which opens the player window and
                        // explains a failure. The sample is not in recents when one happens, so
                        // that alert's clean-up finds nothing to remove.
                        await openRecentDocumentAndPresent(url: Self.spatialAudioSampleURL)
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
