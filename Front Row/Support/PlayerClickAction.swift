//
//  PlayerClickAction.swift
//  Front Row
//
//  Created by Joshua Park on 8/12/26.
//

import Foundation

/// What a left click on the video does. Independent of `NSEvent` and `NSWindow` so the rules can
/// be tested directly, leaving the view holding only the wiring.
enum PlayerClickAction: Equatable {

    /// Move the window with the pointer, so the video is a place to drag the window from.
    case moveWindow

    case toggleFullScreen

    /// Nothing of ours; the click goes on up the responder chain.
    case ignore

    init(clickCount: Int, isFullscreen: Bool) {
        switch clickCount {
        case 1: self = isFullscreen ? .ignore : .moveWindow
        case 2: self = .toggleFullScreen
        default: self = .ignore
        }
    }
}
