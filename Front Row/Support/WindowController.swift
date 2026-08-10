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

    /// Records the player window, reporting whether it's one not seen before. A `true` means the
    /// window has just been created, so anything that needed it and found nothing has to run now.
    ///
    /// A window already held answers `false`, so a repeated report can't re-run window setup and
    /// undo what the user has done to it since.
    @discardableResult
    func adoptMainWindow(_ window: NSWindow) -> Bool {
        guard mainWindow !== window else { return false }
        mainWindow = window
        return true
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
