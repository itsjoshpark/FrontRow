//
//  WindowControllerTests.swift
//  Front Row Tests
//

import AppKit
import Testing

@testable import Front_Row

/// Exercises the shared controller directly, since it owns the only main-window slot there is.
/// The assertions are about a window it has and hasn't seen, so they hold whatever it was
/// holding beforehand.
@MainActor
struct WindowControllerTests {

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
        let controller = WindowController.shared
        let window = makeWindow()

        #expect(controller.adoptMainWindow(window))
        #expect(controller.mainWindow === window)
    }

    /// A window reported twice is still the same window. Treating the second report as a new one
    /// would re-run window setup and undo the user's own resizing.
    @Test
    func theSameWindowIsAdoptedOnlyOnce() {
        let controller = WindowController.shared
        let window = makeWindow()

        controller.adoptMainWindow(window)

        #expect(!controller.adoptMainWindow(window))
    }

    /// Closing the player window and opening another leaves a window that needs setting up again.
    @Test
    func aReplacementWindowIsAdopted() {
        let controller = WindowController.shared
        controller.adoptMainWindow(makeWindow())

        let replacement = makeWindow()

        #expect(controller.adoptMainWindow(replacement))
        #expect(controller.mainWindow === replacement)
    }
}
