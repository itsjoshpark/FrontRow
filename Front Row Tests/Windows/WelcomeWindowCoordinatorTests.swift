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
    private func withCoordinator(
        welcomeWindow: NSWindow?,
        _ body: (_ opened: () -> Int, _ dismissed: () -> Int) -> Void
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
        coordinator.openMainWindow = { counts.opens += 1 }
        coordinator.dismissWelcomeWindow = { counts.dismissals += 1 }
        coordinator.welcomeWindow = welcomeWindow

        body({ counts.opens }, { counts.dismissals })
    }

    /// The player window can appear without the app asking - macOS presents it along with a file
    /// handed to the app - and the welcome window has to go when it does, or the two sit side by
    /// side with an alert hanging from one of them.
    @Test
    func theWelcomeWindowGivesWayToAPlayerWindowTheAppDidntAskFor() {
        let window = makeWindow()
        withCoordinator(welcomeWindow: window) { opened, dismissed in
            coordinator.yieldToMainWindow()

            #expect(dismissed() == 1)
            #expect(opened() == 0, "Yielding shouldn't open anything of its own")
        }
    }

    /// Nothing to give way with. Asking SwiftUI to dismiss a window that isn't on screen would
    /// close whichever one takes the identifier next.
    @Test
    func yieldingWithNoWelcomeWindowDoesNothing() {
        withCoordinator(welcomeWindow: nil) { _, dismissed in
            coordinator.yieldToMainWindow()

            #expect(dismissed() == 0)
        }
    }

    @Test
    func presentingTheMainWindowOpensItAndClosesTheWelcomeWindow() {
        withCoordinator(welcomeWindow: makeWindow()) { opened, dismissed in
            coordinator.presentMainWindow()

            #expect(opened() == 1)
            #expect(dismissed() == 1)
        }
    }

    /// Counters the closures write into. A class so the closures share one instance rather than
    /// each capturing a copy.
    private final class Counts {
        var opens = 0
        var dismissals = 0
    }
}
