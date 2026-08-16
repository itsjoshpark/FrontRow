//
//  PresentedViewManager.swift
//  Front Row
//
//  Created by Joshua Park on 3/19/24.
//

import SwiftUI

@MainActor
@Observable final class PresentedViewManager {

    static let shared = PresentedViewManager()

    var isPresentingOpenURLView = false

    var isPresentingGoToTimeView = false

    /// A recent file that could not be opened.
    ///
    /// Setting this presents an alert. It's set back to `nil` once the alert is dismissed.
    var unopenableRecentFile: UnopenableRecentFile?

    /// Whatever stage of a conversion is asking the user something.
    var remuxAlert: RemuxAlert?

    /// Whether a conversion is running. The sheet reporting on it belongs to AppKit, so this is
    /// only here to keep playback commands disabled while it's up.
    var isConverting = false

    var isPresenting: Bool {
        isPresentingOpenURLView || isPresentingGoToTimeView || unopenableRecentFile != nil
            || remuxAlert != nil || isConverting
    }
}
