//
//  MediaInspectorModel.swift
//  Front Row
//
//  Created by Joshua Park on 8/9/26.
//

import Foundation

@MainActor
@Observable final class MediaInspectorModel {

    private(set) var inspection: MediaInspection?

    func reload(playEngine: PlayEngine) async {
        guard playEngine.isLoaded, let item = playEngine.player.currentItem,
            let url = playEngine.fileURL
        else {
            inspection = nil
            return
        }

        let loaded = await MediaInspectionLoader.load(item: item, url: url)

        // A load outrun by the next file describes the one before it, and every `try?` along the
        // way turns the cancellation into a missing field rather than an error.
        guard !Task.isCancelled else { return }

        inspection = loaded
    }
}
