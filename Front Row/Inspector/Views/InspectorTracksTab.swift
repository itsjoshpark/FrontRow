//
//  InspectorTracksTab.swift
//  Front Row
//
//  Created by Joshua Park on 8/8/26.
//

import CoreMedia
import SwiftUI

/// Every track in the file, one at a time - including the ones playback ignored, which is the
/// point: it's how you find out a file has a second audio track or a subtitle you weren't offered.
struct InspectorTracksTab: View {
    let tracks: [TrackSummary]

    @State private var selectedTrackID: CMPersistentTrackID?

    /// Falls back to the first track so a stale selection from the previous file resolves to
    /// something real instead of an empty pane.
    private var selectedTrack: TrackSummary? {
        tracks.first { $0.id == selectedTrackID } ?? tracks.first
    }

    /// Reads back the track actually being shown rather than the raw state, so the picker names
    /// the fallback instead of sitting blank before anything has been chosen.
    private var selection: Binding<CMPersistentTrackID?> {
        Binding(get: { selectedTrack?.id }, set: { selectedTrackID = $0 })
    }

    var body: some View {
        if tracks.isEmpty {
            InspectorPlaceholder(
                message: Text(
                    "This file has no tracks.", comment: "Inspector placeholder, Tracks tab"))
        } else {
            VStack(spacing: 0) {
                Picker(selection: selection) {
                    ForEach(tracks) { track in
                        Text(verbatim: MediaValueFormat.trackLabel(for: track))
                            .tag(Optional(track.id))
                    }
                } label: {
                    Text("Track", comment: "Picker choosing which track the Inspector describes")
                }
                .controlSize(.small)
                .font(.subheadline)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Divider()

                if let track = selectedTrack {
                    InspectorTrackDetail(track: track)
                }
            }
        }
    }
}

private struct InspectorTrackDetail: View {
    let track: TrackSummary

    var body: some View {
        InspectorGrid {
            InspectorRow(
                label: Text("ID"), value: track.id.formatted(.number.grouping(.never)))
            InspectorRow(label: Text("Type"), value: MediaValueFormat.kindName(track.kind))
            InspectorFlagsRow(
                label: Text("Properties"),
                flags: [
                    (Text("Enabled", comment: "Track property"), track.isEnabled),
                    (Text("Playing", comment: "Track property"), track.isSelected),
                    (
                        Text("Main", comment: "Track property: main program content"),
                        track.isMainProgram
                    ),
                    (Text("Forced", comment: "Track property: forced subtitles"), track.isForced),
                ]
            )
            InspectorRow(label: Text("Title"), value: track.title)
            InspectorRow(label: Text("Language"), value: track.languageName)
            InspectorRow(label: Text("Format"), value: track.formatCode)
            InspectorRow(label: Text("Codec"), value: track.codecName)

            if track.kind == .video {
                InspectorRow(
                    label: Text("Size"), value: track.dimensions.map(MediaValueFormat.dimensions))
                InspectorRow(
                    label: Text("Frame Rate"),
                    value: track.frameRate.map(MediaValueFormat.frameRate))
            }

            if track.kind == .audio {
                InspectorRow(label: Text("Channels"), value: track.channels)
                InspectorRow(
                    label: Text("Sample Rate"),
                    value: track.sampleRate.map(MediaValueFormat.sampleRate))
            }

            InspectorRow(
                label: Text("Bit Rate"), value: track.bitRate.map(MediaValueFormat.bitRate))
            InspectorRow(
                label: Text("Data Size"), value: track.dataSize.map(MediaValueFormat.byteSize))
        }
    }
}
