//
//  WindowControllerTests.swift
//  Front Row Tests
//

import AppKit
import Testing

@testable import Front_Row

/// Exercises the shared controller directly, since it owns the only main-window slot there is.
/// Each test hands the window back before it ends: the slot decides which scene owns an alert and
/// which window to shape, so a leftover test window would answer for a real one.
@MainActor
struct WindowControllerTests {

    private let controller = WindowController.shared

    private let videoSize = CGSize(width: 640, height: 360)

    private func makeWindow() -> NSWindow {
        NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: true
        )
    }

    @Test
    func theWindowIsHeldOnceItExists() {
        let window = makeWindow()
        defer { controller.releaseMainWindow(window) }

        controller.setMainWindow(window)

        #expect(controller.mainWindow === window)
    }

    /// Only the window being held is given up. A closing window that was never the player's is
    /// somebody else's, and letting it clear the slot would lose the real one.
    @Test
    func releasingAWindowThatIsntHeldChangesNothing() {
        let window = makeWindow()
        defer { controller.releaseMainWindow(window) }
        controller.setMainWindow(window)

        controller.releaseMainWindow(makeWindow())

        #expect(controller.mainWindow === window)
    }

    @Test
    func theWindowIsGivenUpWhenItCloses() {
        let window = makeWindow()
        controller.setMainWindow(window)

        controller.releaseMainWindow(window)

        #expect(controller.mainWindow == nil)
    }

    /// The point of the whole arrangement: a size published before there was a window still
    /// shapes the window, because fitting reads the size that stands rather than catching the
    /// moment it arrives.
    @Test
    func aWindowArrivingAfterTheSizeIsStillShapedByIt() {
        let window = makeWindow()
        defer { controller.releaseMainWindow(window) }

        controller.fitToVideoSize(videoSize)  // No window yet - nothing to shape.
        controller.setMainWindow(window)
        controller.fitToVideoSize(videoSize)

        #expect(window.aspectRatio == videoSize)
    }

    @Test
    func aSizeArrivingAfterTheWindowShapesIt() {
        let window = makeWindow()
        defer { controller.releaseMainWindow(window) }
        controller.setMainWindow(window)

        controller.fitToVideoSize(.zero)
        controller.fitToVideoSize(videoSize)

        #expect(window.aspectRatio == videoSize)
    }

    /// Audio has no shape to hold the window to, and the constraint has to be dropped rather than
    /// left at whatever the last video set.
    @Test
    func noVideoSizeDropsTheAspectRatio() {
        let window = makeWindow()
        defer { controller.releaseMainWindow(window) }
        controller.setMainWindow(window)
        controller.fitToVideoSize(videoSize)

        controller.fitToVideoSize(.zero)

        #expect(window.resizeIncrements == NSSize(width: 1.0, height: 1.0))
    }

    /// Full screen is the window's own shape for as long as it lasts, so a file opened there is
    /// held to its aspect ratio without being resized out from under it.
    @Test
    func skippingTheResizeStillHoldsTheAspectRatio() {
        let window = makeWindow()
        defer { controller.releaseMainWindow(window) }
        controller.setMainWindow(window)
        let frameBeforeFit = window.frame

        controller.fitToVideoSize(videoSize, skipResize: true)

        #expect(window.frame == frameBeforeFit)
        #expect(window.aspectRatio == videoSize)
    }
}
