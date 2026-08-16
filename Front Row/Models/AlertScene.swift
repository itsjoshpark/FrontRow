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
}
