//
//  WelcomeWindowCoordinator.swift
//  Front Row
//
//  Created by Joshua Park on 7/17/26.
//

import SwiftUI

/// Bridges SwiftUI's `openWindow`/`dismissWindow` actions to non-View code (`AppDelegate`) and to
/// helpers that shouldn't have to thread those actions through every call.
///
/// `WelcomeView` captures both actions once (they stay valid for the app's lifetime) and stores
/// them here. When the app is launched by opening a file, `presentMainWindow()` may run before
/// those closures exist; it remembers the request and the `didSet` flushes it once both closures
/// become available, so the main window still opens instead of silently no-oping.
@MainActor
@Observable
final class WelcomeWindowCoordinator {

    static let shared = WelcomeWindowCoordinator()

    var openMainWindow: (() -> Void)? {
        didSet { flushPendingPresentIfNeeded() }
    }
    var dismissWelcomeWindow: (() -> Void)? {
        didSet { flushPendingPresentIfNeeded() }
    }

    private var hasPendingPresent = false

    private init() {}

    func presentMainWindow() {
        guard let openMainWindow, let dismissWelcomeWindow else {
            hasPendingPresent = true
            return
        }
        openMainWindow()
        dismissWelcomeWindow()
    }

    private func flushPendingPresentIfNeeded() {
        guard hasPendingPresent, let openMainWindow, let dismissWelcomeWindow else { return }
        hasPendingPresent = false
        openMainWindow()
        dismissWelcomeWindow()
    }
}
