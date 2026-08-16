//
//  VideoWindowSizingModifier.swift
//  Front Row
//

import SwiftUI

/// Keeps the player window shaped to the video it's showing.
///
/// The rule is that the window's shape follows the current video size, so it's applied whenever
/// either half of that changes: a newly published size, or the window itself arriving. The window
/// is created after the file is open, so the size is regularly known first - reading the size
/// that stands rather than catching the moment it's published is what makes the order stop
/// mattering.
///
/// Full screen suppresses the resize but not the aspect ratio, and isn't a trigger of its own:
/// leaving full screen restores the frame the window had going in, which is the size to be back
/// at, and the constraint is already in place by then.
private struct VideoWindowSizingModifier: ViewModifier {
    let playEngine: PlayEngine
    let windowController: WindowController

    func body(content: Content) -> some View {
        content
            .onChange(of: playEngine.videoSize, initial: true) { _, _ in fit() }
            .onChange(of: windowController.mainWindow, initial: true) { _, _ in fit() }
    }

    private func fit() {
        windowController.fitToVideoSize(
            playEngine.videoSize, skipResize: windowController.isFullscreen)
    }
}

extension View {
    /// Shapes the player window to the video being played, for as long as this view is up.
    func videoWindowSizing(playEngine: PlayEngine, windowController: WindowController)
        -> some View
    {
        modifier(
            VideoWindowSizingModifier(playEngine: playEngine, windowController: windowController))
    }
}
