//
//  AlertScene.swift
//  Front Row
//
//  Created by Joshua Park on 8/2/26.
//

import Foundation

/// Which window scene an alert belongs to.
///
/// The alert state is app-wide but each scene applies its own modifier, so a scene has to be named
/// as the owner or both would raise a copy. Recorded when the failure happens rather than derived
/// from focus: presenting an alert takes key away from its own window, so a focus test would
/// suppress the very alert it just allowed.
enum AlertScene {
    case player
    case welcome

    /// The scene to present in right now.
    ///
    /// Keyed on which windows exist rather than on which is frontmost. `presentMainWindow()`
    /// dismisses the welcome window and nothing reopens it, so once the player scene exists it's
    /// the only target left - and launching the app by opening a file skips the welcome window
    /// entirely, which would otherwise be named as the host of an alert nothing can show.
    @MainActor
    static var current: AlertScene {
        guard WelcomeWindowCoordinator.shared.welcomeWindow != nil else { return .player }
        return WindowController.shared.mainWindow == nil ? .welcome : .player
    }

    /// The scene to present in, with a window behind it to present in.
    ///
    /// `current` names the player scene where nothing is open at all, which is right - that is
    /// where the alert belongs - but leaves nobody to show it. Double-clicking a file in the Finder
    /// does exactly that: it skips the welcome window and opens nothing else, so without asking for
    /// the player window here the alert would be raised against no window and never appear. A
    /// question nobody can answer is worse than a late one, since it holds the only slot there is.
    ///
    /// A function rather than a property: reading it can put a window on screen.
    @MainActor
    static func hosting() -> AlertScene {
        let scene = current
        if scene == .player && WindowController.shared.mainWindow == nil {
            WelcomeWindowCoordinator.shared.presentMainWindow()
        }
        return scene
    }
}
