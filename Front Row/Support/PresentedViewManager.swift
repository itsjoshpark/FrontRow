//
//  PresentedViewManager.swift
//  Front Row
//
//  Created by Joshua Park on 3/19/24.
//

import SwiftUI

/// Which window scene an alert belongs to.
///
/// The alert state is app-wide but each scene applies its own modifier, so a scene has to be named
/// as the owner or both would raise a copy. Recorded when the failure happens rather than derived
/// from focus: presenting an alert takes key away from its own window, so a focus test would
/// suppress the very alert it just allowed.
enum AlertScene {
    case player
    case welcome

    /// The scene to present in right now.
    ///
    /// Keyed on whether the player window exists rather than on which window is frontmost.
    /// `presentMainWindow()` dismisses the welcome window and nothing reopens it, so once the
    /// player scene exists it's the only target left.
    @MainActor
    static var current: AlertScene {
        WindowController.shared.mainWindow == nil ? .welcome : .player
    }
}

/// A recent file that couldn't be opened, and everything needed to explain why.
struct UnopenableRecentFile {
    var url: URL
    var result: FileOpenResult
    /// The disconnected volume the file lives on, if that's why it wouldn't open.
    var unavailableVolumeName: String?
    /// The scene that raised this, and so the only one that presents it.
    var scene: AlertScene
}

@MainActor
@Observable public final class PresentedViewManager {

    static let shared = PresentedViewManager()

    var isPresentingOpenURLView = false

    var isPresentingGoToTimeView = false

    /// A recent file that could not be opened.
    ///
    /// Setting this presents an alert. It's set back to `nil` once the alert is dismissed.
    var unopenableRecentFile: UnopenableRecentFile?

    var isPresentingUnopenableRecentFileAlert: Bool {
        get { unopenableRecentFile != nil }
        set {
            if !newValue {
                unopenableRecentFile = nil
            }
        }
    }

    var isPresenting: Bool {
        isPresentingOpenURLView || isPresentingGoToTimeView
            || isPresentingUnopenableRecentFileAlert
    }
}
