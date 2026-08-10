//
//  WindowControllerTests.swift
//  Front Row Tests
//

import AppKit
import Testing

@testable import Front_Row

/// Exercises the shared controller directly, since it owns the only main-window slot there is.
/// Each test hands the window back before it ends: the slot is read to decide which scene owns an
/// alert and which window to resize, so a leftover test window would answer for a real one.
@MainActor
struct WindowControllerTests {

    private let controller = WindowController.shared

    private func makeWindow() -> NSWindow {
        NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: true
        )
    }

    /// The player window is created after the file is open, so the video's size can already have
    /// been published and dropped. A first sighting is what tells the app to apply it.
    @Test
    func aWindowNotSeenBeforeIsAdopted() {
        let window = makeWindow()
        defer { controller.releaseMainWindow(window) }

        #expect(controller.adoptMainWindow(window))
        #expect(controller.mainWindow === window)
    }

    /// A window reported twice is still the same window. Treating the second report as a new one
    /// would re-run window setup and undo the user's own resizing.
    @Test
    func theSameWindowIsAdoptedOnlyOnce() {
        let window = makeWindow()
        defer { controller.releaseMainWindow(window) }
        controller.adoptMainWindow(window)

        #expect(!controller.adoptMainWindow(window))
    }

    /// Closing the player window and opening another leaves a window that needs setting up again.
    @Test
    func aReplacementWindowIsAdopted() {
        let closed = makeWindow()
        controller.adoptMainWindow(closed)
        controller.releaseMainWindow(closed)

        let replacement = makeWindow()
        defer { controller.releaseMainWindow(replacement) }

        #expect(controller.adoptMainWindow(replacement))
        #expect(controller.mainWindow === replacement)
    }

    /// Only the window being held is given up. A closing window that was never the player's is
    /// somebody else's, and letting it clear the slot would lose the real one.
    @Test
    func releasingAWindowThatIsntHeldChangesNothing() {
        let window = makeWindow()
        defer { controller.releaseMainWindow(window) }
        controller.adoptMainWindow(window)

        controller.releaseMainWindow(makeWindow())

        #expect(controller.mainWindow === window)
    }
}
