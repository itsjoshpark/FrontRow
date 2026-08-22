//
//  OpenURLView.swift
//  Front Row
//
//  Created by Joshua Park on 3/17/24.
//

import SwiftUI

/// What the Open URL sheet shows beside its field.
///
/// Kept apart from the view so the one thing worth getting right - which failure the symbol
/// blames - can be tested without a window or a network.
enum OpenURLStatus: Equatable {
    case idle
    case loading
    /// Nothing could be reached, so the address is not the thing to doubt.
    case offline
    /// Reached, or never an address at all, and still wouldn't play.
    case unopenable

    /// The symbol standing in for this status, or `nil` where none is drawn.
    var symbolName: String? {
        switch self {
        case .idle, .loading: nil
        case .offline: "network.slash"
        case .unopenable: "play.slash"
        }
    }

    init(failure result: FileOpenResult) {
        self = result == .offline ? .offline : .unopenable
    }
}

struct OpenURLView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlayEngine.self) private var playEngine: PlayEngine
    @State private var url = ""
    @State private var status = OpenURLStatus.idle

    var body: some View {
        HStack(spacing: 16) {
            if status == .loading {
                ProgressView()
                    .controlSize(.small)
            }

            if let symbolName = status.symbolName {
                Image(systemName: symbolName)
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
                    status = .idle
                }
            }
            .onSubmit {
                Task {
                    guard let url = URL(string: url) else {
                        withAnimation {
                            status = .unopenable
                        }
                        return
                    }
                    status = .loading
                    // A local Matroska URL is handed to the converter, which raises its own alerts
                    // from here. Treating that as a failure would flag the field and hold this
                    // sheet open underneath them.
                    let result = await openFile(url: url)
                    guard result == .opened || result == .handedToConverter else {
                        withAnimation {
                            status = OpenURLStatus(failure: result)
                        }
                        return
                    }
                    withAnimation {
                        status = .idle
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
