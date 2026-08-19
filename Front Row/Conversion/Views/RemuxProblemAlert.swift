//
//  RemuxProblemAlert.swift
//  Front Row
//
//  Created by Joshua Park on 8/15/26.
//

import SwiftUI

/// What the "this file won't be converted" alert offers to do about it.
///
/// Only the missing-tools case has anywhere useful to send someone, and where it sends them depends
/// on whether Homebrew is already there - which is the whole reason this mapping is worth keeping
/// apart from the view.
enum RemuxProblemAlert {

    enum Button: Hashable {
        case ok
        case cancel
        case installFFmpeg
        case installHomebrew
    }

    static func buttons(for reason: RemuxProblem.Reason) -> [Button] {
        switch reason {
        // Pointing someone at the ffmpeg formula is no help if they have no way to install it.
        case .toolsMissing(let hasHomebrew):
            [hasHomebrew ? .installFFmpeg : .installHomebrew, .cancel]
        case .unsupported, .probeFailed: [.ok]
        }
    }

    /// An alert title has to be a `Text`, so this is a function rather than a view.
    static func title(for reason: RemuxProblem.Reason?) -> Text {
        switch reason {
        case .toolsMissing:
            Text(
                "File Needs Conversion",
                comment: "Alert title shown when a file needs converting but ffmpeg is missing"
            )
        case .unsupported, .probeFailed, nil:
            Text(
                "Couldn't Open File",
                comment: "Alert title shown when a file can't be played or converted"
            )
        }
    }

    /// Whether the message should say the file may be broken, rather than merely unsupported.
    static func mayBeDamaged(_ reason: RemuxProblem.Reason) -> Bool {
        reason == .probeFailed
    }
}

struct RemuxProblemButton: View {
    let button: RemuxProblemAlert.Button

    init(_ button: RemuxProblemAlert.Button) {
        self.button = button
    }

    var body: some View {
        switch button {
        case .ok:
            SwiftUI.Button(role: .cancel) {
            } label: {
                Text("OK", comment: "Dismisses the alert shown when a file couldn't be converted")
            }
        case .cancel:
            SwiftUI.Button(role: .cancel) {
            } label: {
                Text("Cancel", comment: "Dismisses the alert shown when ffmpeg isn't installed")
            }
        case .installFFmpeg:
            SwiftUI.Button {
                MediaConversion.openInstallPage(hasHomebrew: true)
            } label: {
                Text(
                    "Install FFmpeg",
                    comment: "Alert button that opens the Homebrew page for the ffmpeg formula"
                )
            }
        case .installHomebrew:
            SwiftUI.Button {
                MediaConversion.openInstallPage(hasHomebrew: false)
            } label: {
                Text(
                    "Install Homebrew",
                    comment: "Alert button that opens the Homebrew website"
                )
            }
        }
    }
}

struct RemuxProblemMessage: View {
    let problem: RemuxProblem

    var body: some View {
        switch problem.reason {
        case .toolsMissing:
            Text(
                "\"\(problem.url.lastPathComponent)\" can be opened after it is converted, but FFmpeg isn't installed. Install it using Homebrew, then open the file again.",
                comment: "Alert message shown when a file needs converting but ffmpeg is missing"
            )
        case .unsupported, .probeFailed:
            Text(
                UnplayableFileMessage.text(
                    for: problem.url,
                    mayBeDamaged: RemuxProblemAlert.mayBeDamaged(problem.reason)
                )
            )
        }
    }
}
