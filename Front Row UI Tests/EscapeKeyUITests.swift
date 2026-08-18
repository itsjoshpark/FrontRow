//
//  EscapeKeyUITests.swift
//  Front Row UI Tests
//

import XCTest

/// What Escape does, which depends on what has focus when it lands.
///
/// `KeyDownListener` takes the key from anywhere in the app and answers it by pausing and hiding,
/// unless something editable is first responder - and that exception is the only thing leaving
/// Escape free to cancel a sheet. Both behaviours come out of the same `guard`, so neither can be
/// changed without the other, and only a running app can say which way it went.
final class EscapeKeyUITests: FrontRowUITestCase {

    /// Escape gets the player off the screen, and stops the file rather than leaving it playing to
    /// an empty room.
    func testEscapeHidesTheAppAndPausesPlayback() async throws {
        // Long enough to still be playing when the menu is read - a short clip would reach its end
        // first and make the paused state look like the key working.
        let movie = try await MediaFixtures.makeMovie(
            size: CGSize(width: 640, height: 360),
            named: "clip",
            in: fixtures,
            seconds: 60,
            frameRate: 2
        )
        try openInFinder(movie)
        waitForSizeToSettle(try playerWindow(for: movie))

        XCTAssertTrue(
            menus.contains("Pause", in: "Playback"),
            "The fixture is not playing, so pausing it would prove nothing"
        )

        activate()
        app.typeKey(.escape, modifierFlags: [])

        XCTAssertTrue(
            app.wait(for: .runningBackground, timeout: 10),
            "Escape left the app on the screen"
        )

        // Brought back before the menu is read: a hidden app has no menu bar to ask, and coming
        // back does not resume anything.
        activate()
        XCTAssertTrue(
            menus.contains("Play", in: "Playback"),
            "Escape hid the app and left the file playing behind it"
        )
    }

    /// The field editor exception, from the sheet's side. With the URL field focused the key is
    /// passed on rather than taken, so AppKit cancels the sheet - and the app stays put.
    func testEscapeClosesTheOpenURLSheetAndLeavesTheAppUp() throws {
        activate()
        app.typeKey("o", modifierFlags: [.command, .shift])

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(
            sheet.textFields.firstMatch.waitForExistence(timeout: 15),
            "The Open URL sheet did not appear"
        )

        app.typeKey(.escape, modifierFlags: [])

        XCTAssertTrue(
            sheet.waitForNonExistence(timeout: 10),
            "Escape left the Open URL sheet up"
        )
        XCTAssertEqual(
            app.state, .runningForeground,
            "Escape closed the sheet and hid the app with it"
        )
    }
}
