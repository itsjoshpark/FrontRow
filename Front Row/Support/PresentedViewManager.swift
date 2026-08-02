//
//  PresentedViewManager.swift
//  Front Row
//
//  Created by Joshua Park on 3/19/24.
//

import SwiftUI

@MainActor
@Observable public final class PresentedViewManager {

    static let shared = PresentedViewManager()

    var isPresentingOpenURLView = false

    var isPresentingGoToTimeView = false

    /// A recent document that couldn't be reached (e.g. its volume isn't mounted, or it was
    /// deleted).
    ///
    /// Setting this asks whether to remove it from recents. It's set back to `nil` once the alert
    /// is dismissed.
    var unavailableRecentDocument: URL?

    var isPresentingUnavailableRecentDocumentAlert: Bool {
        get { unavailableRecentDocument != nil }
        set {
            if !newValue {
                unavailableRecentDocument = nil
            }
        }
    }

    /// The name of a file that was reached but holds no playable content.
    ///
    /// Setting this presents an alert. It's set back to `nil` once the alert is dismissed.
    var unplayableFileName: String?

    var isPresentingUnplayableFileAlert: Bool {
        get { unplayableFileName != nil }
        set {
            if !newValue {
                unplayableFileName = nil
            }
        }
    }

    var isPresenting: Bool {
        isPresentingOpenURLView || isPresentingGoToTimeView
            || isPresentingUnavailableRecentDocumentAlert || isPresentingUnplayableFileAlert
    }
}
