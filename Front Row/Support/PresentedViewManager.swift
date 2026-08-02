//
//  PresentedViewManager.swift
//  Front Row
//
//  Created by Joshua Park on 3/19/24.
//

import SwiftUI

/// Which window scene presents an alert.
///
/// Both scenes can be on screen at once, and a dismissed `Window` scene stays alive and will still
/// present - resurfacing itself in the process - so an alert has to name the scene it belongs to
/// rather than relying on only one being around to show it.
enum AlertScene {
    case player
    case welcome

    /// The scene to present in right now.
    ///
    /// Keyed on whether the player window exists rather than whether it's on screen: presenting
    /// the main window dismisses the welcome window for good - nothing reopens it - so once the
    /// player scene exists it's the only target left. Visibility would misroute while the player
    /// is merely miniaturized or the app is hidden, naming a scene that can't present and leaving
    /// the alert stuck unshown.
    @MainActor
    static var current: AlertScene {
        WindowController.shared.mainWindow == nil ? .welcome : .player
    }
}

/// A recent document that failed to open, and why.
///
/// The reason affects only how the alert is worded - either way the user is asked whether to forget
/// the entry. A file that won't play clutters the list just as much as one that's out of reach, and
/// neither failure is reliably permanent: an incomplete download, an unmaterialized cloud file or a
/// flaky share all fail to load now and play later.
struct UnopenableRecentDocument: Equatable {
    enum Reason {
        /// Couldn't be reached - e.g. its volume isn't mounted, or it was deleted.
        case unavailable

        /// Reached, but holds no playable content.
        case unplayable
    }

    let url: URL
    let reason: Reason
    let scene: AlertScene

    /// Present tense on purpose: neither reason claims the file will never open.
    var alertTitle: Text {
        switch reason {
        case .unavailable:
            Text(
                "\"\(url.lastPathComponent)\" isn't available",
                comment: "Alert title shown when a recent file can't be reached")
        case .unplayable:
            Text(
                "\"\(url.lastPathComponent)\" can't be played",
                comment: "Alert title shown when a recent file holds no playable content")
        }
    }
}

@MainActor
@Observable public final class PresentedViewManager {

    static let shared = PresentedViewManager()

    var isPresentingOpenURLView = false

    var isPresentingGoToTimeView = false

    /// A recent document that couldn't be opened.
    ///
    /// Setting this asks whether to remove it from recents. It's set back to `nil` once the alert
    /// is dismissed.
    var unopenableRecentDocument: UnopenableRecentDocument?

    var isPresentingUnopenableRecentDocumentAlert: Bool {
        get { unopenableRecentDocument != nil }
        set {
            if !newValue {
                unopenableRecentDocument = nil
            }
        }
    }

    var isPresenting: Bool {
        isPresentingOpenURLView || isPresentingGoToTimeView
            || isPresentingUnopenableRecentDocumentAlert
    }
}
