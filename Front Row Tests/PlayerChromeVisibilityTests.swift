//
//  PlayerChromeVisibilityTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

@MainActor
struct PlayerChromeVisibilityTests {

    @Test
    func chromeStartsVisible() {
        let chrome = PlayerChromeVisibility()

        #expect(chrome.areControlsVisible)
        #expect(!chrome.isCursorHidden)
    }

    @Test
    func sittingStillOverTheVideoHidesTheControlsAndThePointer() {
        let chrome = PlayerChromeVisibility()
        chrome.windowHoverChanged(isInside: true)

        chrome.idleElapsed()

        #expect(!chrome.areControlsVisible)
        #expect(chrome.isCursorHidden)
    }

    /// Resting on the controls means the user is about to use them, so nothing may go away
    /// underneath the pointer however long it sits there.
    @Test
    func sittingStillOnTheControlsChangesNothing() {
        let chrome = PlayerChromeVisibility()
        chrome.windowHoverChanged(isInside: true)
        chrome.controlsHoverChanged(isInside: true)

        chrome.idleElapsed()

        #expect(chrome.areControlsVisible)
        #expect(!chrome.isCursorHidden)
    }

    @Test
    func sittingStillOnTheTitleBarChangesNothing() {
        let chrome = PlayerChromeVisibility()
        chrome.titleBarHoverChanged(isInside: true)

        chrome.idleElapsed()

        #expect(chrome.areControlsVisible)
        #expect(!chrome.isCursorHidden)
    }

    @Test
    func movingAgainBringsEverythingBack() {
        let chrome = PlayerChromeVisibility()
        chrome.windowHoverChanged(isInside: true)
        chrome.idleElapsed()

        chrome.mouseMoved()

        #expect(chrome.areControlsVisible)
        #expect(!chrome.isCursorHidden)
    }

    @Test
    func leavingTheWindowHidesTheControls() {
        let chrome = PlayerChromeVisibility()
        chrome.windowHoverChanged(isInside: true)

        chrome.windowHoverChanged(isInside: false)

        #expect(!chrome.areControlsVisible)
        #expect(!chrome.isCursorHidden)
    }

    /// The titlebar sits outside the SwiftUI hierarchy, so reaching for it reads as leaving the
    /// window. The chrome has to stay up or it would vanish just as it is being aimed at.
    @Test
    func reachingForTheTitleBarKeepsTheControlsUp() {
        let chrome = PlayerChromeVisibility()
        chrome.windowHoverChanged(isInside: true)
        chrome.titleBarHoverChanged(isInside: true)

        chrome.windowHoverChanged(isInside: false)

        #expect(chrome.areControlsVisible)
    }

    @Test
    func leavingTheTitleBarForNowhereHidesTheControls() {
        let chrome = PlayerChromeVisibility()
        chrome.titleBarHoverChanged(isInside: true)

        chrome.titleBarHoverChanged(isInside: false)

        #expect(!chrome.areControlsVisible)
    }

    /// The pointer belongs to whatever the user is now over. Hiding it because our window went
    /// idle would take it away from another app entirely.
    @Test
    func sittingStillOutsideTheWindowNeverHidesThePointer() {
        let chrome = PlayerChromeVisibility()
        chrome.windowHoverChanged(isInside: false)

        chrome.idleElapsed()

        #expect(!chrome.isCursorHidden)
    }
}
