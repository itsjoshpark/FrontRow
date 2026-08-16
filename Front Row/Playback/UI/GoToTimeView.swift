//
//  GoToTimeView.swift
//  Front Row
//
//  Created by Joshua Park on 3/19/24.
//

import SwiftUI

struct GoToTimeView: View {
    @Environment(PlayEngine.self) private var playEngine: PlayEngine
    @Namespace private var timeNamespace
    @State private var timecode = ""

    var body: some View {
        VStack {
            TextField(text: $timecode, prompt: Text(verbatim: "0:00:00")) {}
                .autocorrectionDisabled()
                .lineLimit(1)
                .prefersDefaultFocus(in: timeNamespace)

            Button("Go") {
                Task { await playEngine.goToTime(timecode) }
            }

            Button("Cancel", role: .cancel) {
                /// Any action button will dismiss the alert
            }
        }
        .focusScope(timeNamespace)
    }
}

#Preview {
    GoToTimeView()
        .environment(PlayEngine.shared)
}
