//
//  MediaSelectionPickers.swift
//  Front Row
//
//  Created by Joshua Park on 8/5/26.
//

import AVKit
import SwiftUI

/// Picks the subtitle track, or states that the file has none.
///
/// The engine is passed in rather than read from the environment because `Commands` bodies build
/// outside any view hierarchy that would carry it.
struct SubtitlePicker: View {
    @Bindable var playEngine: PlayEngine

    var body: some View {
        if let group = playEngine.subtitleGroup {
            Picker("Subtitle", selection: $playEngine.subtitle) {
                Text("Off").tag(nil as AVMediaSelectionOption?)

                ForEach(group.selectableSubtitleOptions, id: \.stableID) { option in
                    Text(verbatim: option.displayName).tag(Optional(option))
                }
            }
            .pickerStyle(.inline)
        } else {
            Picker("Subtitle", selection: .constant(0)) {
                Text("None").tag(0)
            }
            .pickerStyle(.inline)
            .disabled(true)
        }
    }
}

/// Picks the audio track, or states that the file has none.
struct AudioTrackPicker: View {
    @Bindable var playEngine: PlayEngine

    var body: some View {
        if let group = playEngine.audioGroup {
            Picker("Audio Track", selection: $playEngine.audioTrack) {
                Text("Off").tag(nil as AVMediaSelectionOption?)

                ForEach(group.options, id: \.stableID) { option in
                    Text(verbatim: option.displayName).tag(Optional(option))
                }
            }
        } else {
            Picker("Audio Track", selection: .constant(0)) {
                Text("None").tag(0)
            }
            .disabled(true)
        }
    }
}
