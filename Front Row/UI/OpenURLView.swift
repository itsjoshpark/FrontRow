//
//  OpenURLView.swift
//  Front Row
//
//  Created by Joshua Park on 3/17/24.
//

import SwiftUI

struct OpenURLView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlayEngine.self) private var playEngine: PlayEngine
    @State private var url = ""
    @State private var displayLoading = false
    @State private var displayError = false

    var body: some View {
        HStack(spacing: 16) {
            if displayLoading {
                ProgressView()
                    .controlSize(.small)
            }

            if displayError {
                Image(systemName: "play.slash")
                    .foregroundStyle(.secondary)
                    .font(.largeTitle)
            }

            TextField(
                text: $url,
                prompt: Text(
                    "Enter URL",
                    comment: "Prompt text for Open URL sheet text field"
                )
            ) {}
            .onChange(of: url) {
                playEngine.cancelLoading()
                withAnimation {
                    displayLoading = false
                    displayError = false
                }
            }
            .onSubmit {
                Task {
                    guard let url = URL(string: url) else {
                        withAnimation {
                            displayLoading = false
                            displayError = true
                        }
                        return
                    }
                    displayLoading = true
                    // A local Matroska URL is handed to the converter, which raises its own alerts
                    // from here. Treating that as a failure would flag the field and hold this
                    // sheet open underneath them.
                    let result = await openFile(url: url)
                    guard result == .opened || result == .handedToConverter else {
                        withAnimation {
                            displayLoading = false
                            displayError = true
                        }
                        return
                    }
                    withAnimation {
                        displayLoading = false
                        displayError = false
                    }
                    dismiss()
                }
            }
            .autocorrectionDisabled()
            .lineLimit(1)
            .font(.title)
            .textFieldStyle(.plain)
        }
        .padding([.horizontal], 26)
    }
}

#Preview {
    OpenURLView()
        .environment(PlayEngine.shared)
}
