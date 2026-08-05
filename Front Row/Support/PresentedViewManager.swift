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
