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
        let view = NSView()
        // The view has no window until it's been added to one, which hasn't happened yet.
        Task { [weak view] in
            guard let window = view?.window else { return }
            callback(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        callback(window)
    }
}
