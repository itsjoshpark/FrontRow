//
//  AudioTrackPicker.swift
//  Front Row
//
//  Created by Joshua Park on 8/5/26.
//

import AVKit
import SwiftUI

/// Picks the audio track, or states that the file has none.
struct AudioTrackPicker: View {
    @Bindable var playEngine: PlayEngine

    var body: some View {
        if playEngine.audioChoices.isEmpty {
            Picker("Audio Track", selection: .constant(0)) {
                Text("None").tag(0)
            }
            .disabled(true)
        } else {
            Picker("Audio Track", selection: $playEngine.audioTrack) {
                Text("Off").tag(nil as MediaTrackChoice?)

                ForEach(playEngine.audioChoices) { choice in
                    Text(verbatim: choice.name).tag(Optional(choice))
                }
            }
        }
    }
}
