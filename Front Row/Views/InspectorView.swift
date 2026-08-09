//
//  InspectorView.swift
//  Front Row
//
//  Created by Joshua Park on 8/8/26.
//

import SwiftUI

enum InspectorTab: Hashable, CaseIterable {
    case general
    case tracks
    case file
}

/// Describes the file currently open in the player.
///
/// The inspection is loaded here rather than in `PlayEngine`, so opening a file costs nothing
/// while this window is closed. It's a snapshot of the asset - nothing in it changes during
/// playback - so it's read once per file and left alone.
struct InspectorView: View {
    @Environment(PlayEngine.self) private var playEngine: PlayEngine
    @State private var model = MediaInspectorModel()
    @State private var selectedTab: InspectorTab = .general

    var body: some View {
        VStack(spacing: 0) {
            Picker(selection: $selectedTab) {
                Text("General", comment: "Inspector tab").tag(InspectorTab.general)
                Text("Tracks", comment: "Inspector tab").tag(InspectorTab.tracks)
                Text("File", comment: "Inspector tab").tag(InspectorTab.file)
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider()

            if let inspection = model.inspection {
                switch selectedTab {
                case .general:
                    InspectorGeneralTab(inspection: inspection)
                case .tracks:
                    InspectorTracksTab(tracks: inspection.tracks)
                case .file:
                    InspectorFileTab(file: inspection.file)
                }
            } else {
                InspectorPlaceholder(
                    message: Text(
                        "No media is playing.",
                        comment: "Inspector placeholder when nothing is open"))
            }
        }
        .frame(minWidth: 420, minHeight: 320)
        // Reloads when the window opens, and again once a newly opened file is ready to describe.
        .task(id: playEngine.isLoaded ? playEngine.fileURL : nil) {
            await model.reload(playEngine: playEngine)
        }
        // A panel alongside the player has nowhere useful to minimise or zoom to, so closing is
        // the only control it needs. Resizing by the window's edges still works.
        .background(
            WindowAccessor { window in
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
            }
        )
    }
}

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

        inspection = await MediaInspectionLoader.load(item: item, url: url)
    }
}
