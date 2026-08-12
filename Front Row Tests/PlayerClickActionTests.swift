//
//  PlayerClickActionTests.swift
//  Front Row Tests
//

import Testing

@testable import Front_Row

struct PlayerClickActionTests {

    @Test
    func aSingleClickOnTheVideoMovesTheWindow() {
        #expect(PlayerClickAction(clickCount: 1, isFullscreen: false) == .moveWindow)
    }

    @Test
    func aDoubleClickTogglesFullscreen() {
        #expect(PlayerClickAction(clickCount: 2, isFullscreen: false) == .toggleFullScreen)
    }

    /// Double-clicking is the only way back out by mouse, so it has to keep working there too.
    @Test
    func aDoubleClickStillTogglesInFullscreen() {
        #expect(PlayerClickAction(clickCount: 2, isFullscreen: true) == .toggleFullScreen)
    }

    /// A fullscreen window has nowhere to move to, and dragging it fights the space it's in.
    @Test
    func aSingleClickInFullscreenDoesNothing() {
        #expect(PlayerClickAction(clickCount: 1, isFullscreen: true) == .ignore)
    }

    @Test
    func furtherClicksDoNothing() {
        for clickCount in 3...5 {
            #expect(PlayerClickAction(clickCount: clickCount, isFullscreen: false) == .ignore)
        }
    }

    @Test
    func aClickCountOfZeroIsntAClick() {
        #expect(PlayerClickAction(clickCount: 0, isFullscreen: false) == .ignore)
    }
}
