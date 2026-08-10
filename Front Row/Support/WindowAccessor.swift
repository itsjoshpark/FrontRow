//
//  WindowAccessor.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import SwiftUI

/// Gives access to the `NSWindow` backing a SwiftUI view, as soon as it exists - unlike relying
/// on `NSApp.mainWindow`/`NSApp.keyWindow` at some later point, which can be the wrong window
/// once the app has more than one `Window` scene.
struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        WindowReportingView(callback: callback)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let nsView = nsView as? WindowReportingView else { return }
        nsView.callback = callback
    }
}

/// Reports its window the moment AppKit attaches one. A view has no window until it's added to
/// one, which happens after it's made, so anything asking earlier - or on a guess at how long
/// that takes - can come away with nothing.
private final class WindowReportingView: NSView {
    var callback: (NSWindow) -> Void

    init(callback: @escaping (NSWindow) -> Void) {
        self.callback = callback
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        callback(window)
    }
}
