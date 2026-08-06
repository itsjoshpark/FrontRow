//
//  PlayerChromeVisibility.swift
//  Front Row
//
//  Created by Joshua Park on 8/5/26.
//

import SwiftUI

/// Decides whether the player's chrome - the controls bar, the titlebar and the pointer - should
/// be on screen.
///
/// Kept apart from the view so the rules can be tested. Which hover keeps the controls up, and
/// which idle actually hides the pointer, are easy to get subtly wrong and impossible to check
/// through a real window. The view is left holding only the wiring: report what the mouse did,
/// apply what comes back.
@MainActor
@Observable
final class PlayerChromeVisibility {

    /// How long the mouse must sit still before the chrome goes away.
    static let idleDelay: Duration = .seconds(3)

    private(set) var areControlsVisible = true

    /// The pointer is only ever hidden over the video itself. Over the controls or the titlebar
    /// the user is aiming at something, and taking the pointer away would strand them.
    private(set) var isCursorHidden = false

    private var isMouseInsideWindow = false
    private var isMouseInTitleBar = false
    private var isMouseInPlayerControls = false

    private var idleTask: Task<Void, Never>?

    /// Whether the pointer is resting on something interactive, which keeps the chrome up however
    /// long it sits still.
    private var isPointingAtChrome: Bool {
        isMouseInTitleBar || isMouseInPlayerControls
    }

    /// The mouse moved somewhere over the window.
    func mouseMoved() {
        areControlsVisible = true
        isCursorHidden = false
        restartIdleCountdown()
    }

    func windowHoverChanged(isInside: Bool) {
        isMouseInsideWindow = isInside
        guard !isInside else {
            mouseMoved()
            return
        }

        // The pointer is somewhere else entirely now, so it must be visible wherever it went.
        isCursorHidden = false
        if !isPointingAtChrome {
            areControlsVisible = false
        }
    }

    func controlsHoverChanged(isInside: Bool) {
        isMouseInPlayerControls = isInside
        if isInside {
            mouseMoved()
        }
    }

    func titleBarHoverChanged(isInside: Bool) {
        isMouseInTitleBar = isInside
        if isInside {
            mouseMoved()
        } else if !isMouseInsideWindow && !isMouseInPlayerControls {
            areControlsVisible = false
        }
    }

    /// The idle countdown ran out. Called by the countdown, and directly by tests so they don't
    /// have to wait it out.
    func idleElapsed() {
        guard !isPointingAtChrome else { return }
        areControlsVisible = false
        isCursorHidden = isMouseInsideWindow
    }

    private func restartIdleCountdown() {
        idleTask?.cancel()
        idleTask = Task { [weak self] in
            try? await Task.sleep(for: Self.idleDelay)
            guard !Task.isCancelled else { return }
            self?.idleElapsed()
        }
    }
}
