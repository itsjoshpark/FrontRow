//
//  InspectorPresentation.swift
//  Front Row
//
//  Created by Joshua Park on 8/9/26.
//

import SwiftUI

/// Whether the Inspector panel is open, so the menu item can name the thing it's about to do.
///
/// Tracked from the panel's content appearing rather than from `NSWindow.isVisible`, which is
/// still `false` while a window restored at launch is being put back on screen - a panel the app
/// reopened for itself would report closed.
@MainActor
@Observable final class InspectorPresentation {

    static let shared = InspectorPresentation()

    private(set) var isOpen = false

    private init() {}

    func windowAppeared() {
        isOpen = true
    }

    func windowDisappeared() {
        isOpen = false
    }
}
