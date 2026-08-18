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
/// them here. A file opened early enough reaches this before those closures exist - the welcome
/// window is recorded from `WindowReader` and the actions from a `task`, in no fixed order - so a
/// request made in that gap is remembered and the `didSet` flushes it, rather than no-oping.
@MainActor
@Observable
final class WelcomeWindowCoordinator {

    static let shared = WelcomeWindowCoordinator()

    var openMainWindow: (() -> Void)? {
        didSet { flushPendingRequestIfNeeded() }
    }
    var dismissWelcomeWindow: (() -> Void)? {
        didSet { flushPendingRequestIfNeeded() }
    }

    /// The welcome window, while it's on screen.
    ///
    /// It usually is at launch, but not always: opening the app by double-clicking a file goes
    /// straight past it. Anything looking for a window to hang an alert or a sheet from has to
    /// know that, and a sheet needs the window itself rather than just the fact of it.
    weak var welcomeWindow: NSWindow?

    private var hasPendingPresent = false
    private var hasPendingYield = false

    private init() {}

    func presentMainWindow() {
        guard let openMainWindow, let dismissWelcomeWindow else {
            hasPendingPresent = true
            return
        }
        openMainWindow()
        dismissWelcomeWindow()
    }

    /// Closes the welcome window without opening anything in its place, for a player window that
    /// is already there.
    ///
    /// The player window doesn't only appear because the app asked: macOS presents it along with a
    /// file handed to the app, before there is anything to play in it. The welcome window gives way
    /// to the player either way - both on screen at once leaves the user looking at one window
    /// while an alert or a sheet hangs from the other.
    func yieldToMainWindow() {
        guard welcomeWindow != nil else { return }
        guard let dismissWelcomeWindow else {
            hasPendingYield = true
            return
        }
        dismissWelcomeWindow()
    }

    /// Runs whichever request was made before the actions to carry it out existed.
    ///
    /// A pending present covers a pending yield: it closes the welcome window itself. Either is
    /// spent once the actions arrive, so a welcome window that closed in the meantime leaves
    /// nothing behind to fire at the next one.
    private func flushPendingRequestIfNeeded() {
        if hasPendingPresent, let openMainWindow, let dismissWelcomeWindow {
            hasPendingPresent = false
            hasPendingYield = false
            openMainWindow()
            dismissWelcomeWindow()
            return
        }

        if hasPendingYield, let dismissWelcomeWindow {
            hasPendingYield = false
            if welcomeWindow != nil { dismissWelcomeWindow() }
        }
    }
}
