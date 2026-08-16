//
//  WindowController.swift
//  Front Row
//
//  Created by Joshua Park on 3/11/24.
//

import SwiftUI

@MainActor
@Observable final class WindowController {

    static let shared = WindowController()

    private var mouseMovedMonitor: Any?

    /// The app's main player window, captured once it's created (it's a singleton `Window`
    /// scene). Used to distinguish it from transient windows (e.g. a menu's own backing window)
    /// when handling window-level notifications that don't otherwise specify which window they
    /// came from.
    private(set) var mainWindow: NSWindow?

    /// Records the player window once it exists. Observed rather than just stored: whether there
    /// is a window to shape is half of what decides the window's shape.
    func setMainWindow(_ window: NSWindow) {
        guard mainWindow !== window else { return }
        mainWindow = window
    }

    /// Lets go of the player window as it closes. A closed window left in place would answer for
    /// a real one, and its replacement would look like a window already dealt with.
    func releaseMainWindow(_ window: NSWindow) {
        guard mainWindow === window else { return }
        mainWindow = nil
    }

    // MARK: - Video Sizing

    /// Shapes the player window to the video it's showing: sized to the video where that fits on
    /// screen, and held to its aspect ratio from then on.
    ///
    /// Safe to call whenever either half of that changes, and does nothing until both are known.
    /// A video with no size to speak of - audio, or a size not published yet - drops the
    /// constraint instead, since `resizeIncrements` and `aspectRatio` displace each other.
    func fitToVideoSize(_ videoSize: CGSize, skipResize: Bool = false) {
        guard let window = mainWindow else { return }

        // Audio, or a size not published yet. `resizeIncrements` and `aspectRatio` displace each
        // other, so setting increments is how the constraint comes off.
        guard videoSize != .zero else {
            window.resizeIncrements = NSSize(width: 1.0, height: 1.0)
            return
        }

        // Only the resize needs somewhere to be placed. The constraint holds regardless, so a
        // window that can't name a screen yet still comes out the right shape.
        if !skipResize, let screen = window.screen ?? NSScreen.main,
            let newFrame = VideoWindowLayout.frame(
                forVideoSize: videoSize, in: screen.visibleFrame)
        {
            window.setFrame(newFrame, display: true, animate: true)
        }
        window.aspectRatio = videoSize
    }

    // MARK: - Mouse Tracking

    /// Whether the pointer is over the titlebar, which SwiftUI can't report since the titlebar
    /// isn't part of the view hierarchy. `PlayerChromeVisibility` decides what to do about it.
    private(set) var isMouseInTitleBar = false

    private init() {
        setupMouseTracking()
    }

    private func setupMouseTracking() {
        mouseMovedMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) {
            [weak self] event in
            self?.updateMousePosition()
            return event
        }
    }

    private func updateMousePosition() {
        guard let window = NSApp.mainWindow else {
            isMouseInTitleBar = false
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = window.frame

        guard windowFrame.contains(mouseLocation) else {
            isMouseInTitleBar = false
            return
        }

        // Convert screen point to window coordinates
        let windowPoint = window.convertPoint(fromScreen: mouseLocation)
        // contentLayoutRect excludes the title bar area
        let contentRect = window.contentLayoutRect

        // Mouse is in title bar if it's above the content rect
        isMouseInTitleBar = windowPoint.y > contentRect.maxY
    }

    // MARK: - Fullscreen

    private(set) var isFullscreen = false

    func setIsFullscreen(_ isFullscreen: Bool) {
        self.isFullscreen = isFullscreen
    }

    // MARK: - Float on Top

    /// Targets the player window specifically. `NSApp.mainWindow` would follow focus, so with the
    /// Inspector open the toggle would report - and change - the wrong window's level.
    var isOnTop: Bool {
        get {
            access(keyPath: \.isOnTop)
            return mainWindow?.level == .floating
        }
        set {
            withMutation(keyPath: \.isOnTop) {
                mainWindow?.level = newValue ? .floating : .normal
            }
        }
    }

    // MARK: - Autohide Cursor

    func hideCursor() {
        CGDisplayHideCursor(CGMainDisplayID())
    }

    func showCursor() {
        CGDisplayShowCursor(CGMainDisplayID())
    }

    // MARK: - Autohide Titlebar

    private var _titlebarView: NSView?

    var titlebarView: NSView? {
        guard _titlebarView == nil else { return _titlebarView }

        guard let containerClass = NSClassFromString("NSTitlebarContainerView") else { return nil }
        guard
            let containerView = NSApp.mainWindow?.contentView?.superview?.subviews.reversed()
                .first(where: { $0.isKind(of: containerClass) })
        else { return nil }

        _titlebarView = containerView
        return _titlebarView
    }

    func hideTitlebar() {
        setTitlebarOpacity(0.0)
    }

    func showTitlebar(immediately: Bool = false) {
        setTitlebarOpacity(1.0, immediately: immediately)
    }

    private func setTitlebarOpacity(_ opacity: CGFloat, immediately: Bool = false) {
        /// when the window is in full screen, the titlebar view is in another window (the "toolbar window")
        guard titlebarView?.window == NSApp.mainWindow else { return }

        if immediately {
            self.titlebarView?.animator().alphaValue = opacity
            return
        }

        NSAnimationContext.runAnimationGroup(
            { ctx in
                ctx.duration = 0.4
                self.titlebarView?.animator().alphaValue = opacity
            }, completionHandler: nil)
    }
}
