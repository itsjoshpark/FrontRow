//
//  PresentedViewManager.swift
//  Front Row
//
//  Created by Joshua Park on 3/19/24.
//

import SwiftUI

/// A recent file that couldn't be opened, and everything needed to explain why.
struct UnopenableRecentFile {
    var url: URL
    var result: FileOpenResult
    /// The disconnected volume the file lives on, if that's why it wouldn't open.
    var unavailableVolumeName: String?
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
