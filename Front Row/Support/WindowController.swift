//
//  WindowController.swift
//  Front Row
//
//  Created by Joshua Park on 3/11/24.
//

import SwiftUI

@Observable public final class WindowController {

    static let shared = WindowController()

    private var mouseMovedMonitor: Any?

    // MARK: - Mouse Tracking

    private(set) var isMouseInTitleBar = false
    var isMouseInPlayerControls = false

    init() {
        setupMouseTracking()
    }

    deinit {
        if let monitor = mouseMovedMonitor {
            NSEvent.removeMonitor(monitor)
        }
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

    var isOnTop: Bool {
        get {
            access(keyPath: \.isOnTop)
            return NSApplication.shared.mainWindow?.level == .floating
        }
        set {
            withMutation(keyPath: \.isOnTop) {
                NSApplication.shared.mainWindow?.level = newValue ? .floating : .normal
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
            let containerView = NSApp.windows.first?.contentView?.superview?.subviews.reversed()
                .first(where: { $0.isKind(of: containerClass) })
        else { return nil }

        guard let titlebarClass = NSClassFromString("NSTitlebarView") else { return nil }
        guard let titlebar = containerView.subviews.first(where: { $0.isKind(of: titlebarClass) })
        else { return nil }

        _titlebarView = titlebar

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
        guard titlebarView?.window == NSApp.windows.first else { return }

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
