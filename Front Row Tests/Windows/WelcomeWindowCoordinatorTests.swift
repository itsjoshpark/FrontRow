//
//  WelcomeWindowCoordinatorTests.swift
//  Front Row Tests
//

import AppKit
import Testing

@testable import Front_Row

/// Exercises the shared coordinator directly, since it owns the only welcome-window slot there is.
/// Serialized for the same reason, and each test puts the slot and the closures back as it found
/// them so a leftover doesn't answer for a real window.
@MainActor
@Suite(.serialized)
struct WelcomeWindowCoordinatorTests {

    private let coordinator = WelcomeWindowCoordinator.shared

    private func makeWindow() -> NSWindow {
        NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
    }

    /// Runs `body` with the coordinator's wiring replaced, and restores it afterwards.
    ///
    /// `wired` false leaves the window actions unset, which is how the coordinator starts out:
    /// `WelcomeView` records the window from `WindowReader` and the actions from a `task`, and
    /// nothing orders those two. `wire()` supplies them, as that `task` eventually does.
    private func withCoordinator(
        welcomeWindow: NSWindow?,
        wired: Bool = true,
        _ body: (_ counts: Counts, _ wire: () -> Void) -> Void
    ) {
        let savedOpen = coordinator.openMainWindow
        let savedDismiss = coordinator.dismissWelcomeWindow
        let savedWindow = coordinator.welcomeWindow
        defer {
            coordinator.openMainWindow = savedOpen
            coordinator.dismissWelcomeWindow = savedDismiss
            coordinator.welcomeWindow = savedWindow
        }

        let counts = Counts()
        let wire = {
            coordinator.openMainWindow = { counts.opens += 1 }
            coordinator.dismissWelcomeWindow = { counts.dismissals += 1 }
        }

        coordinator.openMainWindow = nil
        coordinator.dismissWelcomeWindow = nil
        coordinator.welcomeWindow = welcomeWindow
        if wired { wire() }

        body(counts, wire)
    }

    /// The player window can appear without the app asking - macOS presents it along with a file
    /// handed to the app - and the welcome window has to go when it does, or the two sit side by
    /// side with an alert hanging from one of them.
    @Test
    func theWelcomeWindowGivesWayToAPlayerWindowTheAppDidntAskFor() {
        let window = makeWindow()
        withCoordinator(welcomeWindow: window) { counts, _ in
            coordinator.yieldToMainWindow()

            #expect(counts.dismissals == 1)
            #expect(counts.opens == 0, "Yielding shouldn't open anything of its own")
        }
    }

    /// Nothing to give way with. Asking SwiftUI to dismiss a window that isn't on screen would
    /// close whichever one takes the identifier next.
    @Test
    func yieldingWithNoWelcomeWindowDoesNothing() {
        withCoordinator(welcomeWindow: nil) { counts, _ in
            coordinator.yieldToMainWindow()

            #expect(counts.dismissals == 0)
        }
    }

    /// A file opened while the app is still starting reaches the coordinator between the welcome
    /// window being recorded and the window actions arriving. Dropped there, the two windows stay
    /// on screen together for the rest of the run.
    @Test
    func aYieldMadeBeforeTheWindowActionsArriveIsStillCarriedOut() {
        withCoordinator(welcomeWindow: makeWindow(), wired: false) { counts, wire in
            coordinator.yieldToMainWindow()
            #expect(counts.dismissals == 0, "There is nothing to dismiss with yet")

            wire()

            #expect(counts.dismissals == 1)
            #expect(counts.opens == 0, "Yielding shouldn't open anything of its own")
        }
    }

    /// The welcome window closed on its own in the meantime, so the request has nothing left to do.
    @Test
    func aPendingYieldIsDroppedIfTheWelcomeWindowGoesFirst() {
        withCoordinator(welcomeWindow: makeWindow(), wired: false) { counts, wire in
            coordinator.yieldToMainWindow()
            coordinator.welcomeWindow = nil

            wire()

            #expect(counts.dismissals == 0)
        }
    }

    @Test
    func presentingTheMainWindowOpensItAndClosesTheWelcomeWindow() {
        withCoordinator(welcomeWindow: makeWindow()) { counts, _ in
            coordinator.presentMainWindow()

            #expect(counts.opens == 1)
            #expect(counts.dismissals == 1)
        }
    }

    /// The same gap on the present path, which is what the pending flush was written for.
    @Test
    func aPresentMadeBeforeTheWindowActionsArriveIsStillCarriedOut() {
        withCoordinator(welcomeWindow: makeWindow(), wired: false) { counts, wire in
            coordinator.presentMainWindow()
            #expect(counts.opens == 0)

            wire()

            #expect(counts.opens == 1)
            #expect(counts.dismissals == 1)
        }
    }

    /// Counters the closures write into. A class so the closures share one instance rather than
    /// each capturing a copy.
    private final class Counts {
        var opens = 0
        var dismissals = 0
    }
}
