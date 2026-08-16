//
//  WindowControllerTests.swift
//  Front Row Tests
//

import AppKit
import Testing

@testable import Front_Row

/// Exercises the shared controller directly, since it owns the only main-window slot there is.
/// Serialized for the same reason: the tests would otherwise pass windows into one slot at once,
/// and an animated `setFrame` spins the run loop, which lets them interleave mid-test. Each test
/// hands its window back before it ends, so a leftover doesn't answer for a real one.
///
/// These cover the shaping itself. Which moments it's applied at is `VideoWindowSizing`'s doing,
/// and lives in the SwiftUI lifecycle rather than here.
@MainActor
@Suite(.serialized)
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

    /// Fitting reads the size that stands rather than the moment it arrived, so a size published
    /// before there was a window still shapes the window once one turns up. This is what lets the
    /// two arrive in either order.
    @Test
    func aSizePublishedBeforeTheWindowStillShapesIt() {
        let window = makeWindow()
        defer { controller.releaseMainWindow(window) }

        controller.fitToVideoSize(videoSize, skipResize: true)  // No window yet - nothing to shape.
        controller.setMainWindow(window)
        controller.fitToVideoSize(videoSize, skipResize: true)

        #expect(window.aspectRatio == videoSize)
    }

    @Test
    func aSizeArrivingAfterTheWindowShapesIt() {
        let window = makeWindow()
        defer { controller.releaseMainWindow(window) }
        controller.setMainWindow(window)

        controller.fitToVideoSize(.zero, skipResize: true)
        controller.fitToVideoSize(videoSize, skipResize: true)

        #expect(window.aspectRatio == videoSize)
    }

    /// Audio has no shape to hold the window to, and the constraint has to come off rather than
    /// be left at whatever the last video set.
    @Test
    func noVideoSizeDropsTheAspectRatio() {
        let window = makeWindow()
        defer { controller.releaseMainWindow(window) }
        controller.setMainWindow(window)
        controller.fitToVideoSize(videoSize, skipResize: true)

        controller.fitToVideoSize(.zero, skipResize: true)

        #expect(window.resizeIncrements == NSSize(width: 1.0, height: 1.0))
    }

    /// Only the resize needs a screen to place the window on. A window that can't name one yet
    /// still has to come out the right shape, since nothing would come back to correct it.
    @Test
    func theAspectRatioIsHeldEvenWithNoResize() {
        let window = makeWindow()
        defer { controller.releaseMainWindow(window) }
        controller.setMainWindow(window)
        let frameBeforeFit = window.frame

        controller.fitToVideoSize(videoSize, skipResize: true)

        #expect(window.frame == frameBeforeFit)
        #expect(window.aspectRatio == videoSize)
    }

    /// The window is placed on screen at the video's size when it fits, which is the one path
    /// that needs a screen.
    @Test
    func fittingResizesTheWindowToTheVideo() {
        let window = makeWindow()
        defer { controller.releaseMainWindow(window) }
        controller.setMainWindow(window)

        controller.fitToVideoSize(videoSize)

        #expect(window.aspectRatio == videoSize)
        #expect(window.frame.size == videoSize)
    }
}
