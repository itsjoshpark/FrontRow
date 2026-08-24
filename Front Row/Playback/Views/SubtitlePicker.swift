//
//  SubtitlePicker.swift
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
        if playEngine.subtitleChoices.isEmpty {
            Picker("Subtitle", selection: .constant(0)) {
                Text("None").tag(0)
            }
            .pickerStyle(.inline)
            .disabled(true)
        } else {
            Picker("Subtitle", selection: $playEngine.subtitle) {
                Text("Off").tag(nil as MediaTrackChoice?)

                ForEach(playEngine.subtitleChoices) { choice in
                    Text(verbatim: choice.name).tag(Optional(choice))
                }
            }
            .pickerStyle(.inline)
        }
    }
}
