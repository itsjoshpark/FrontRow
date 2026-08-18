//
//  EscapeKeyUITests.swift
//  Front Row UI Tests
//

import XCTest

/// What Escape does, which depends on what has focus when it lands.
///
/// `KeyDownListener` takes the key from anywhere in the app and answers it by pausing and hiding,
/// unless something editable is first responder. That exception is the only thing leaving Escape
/// free to cancel a sheet, and both behaviours come out of the same `guard`.
final class EscapeKeyUITests: FrontRowUITestCase {

    /// Escape gets the player off the screen.
    func testEscapeHidesTheApp() async throws {
        let movie = try await MediaFixtures.makeMovie(
            size: CGSize(width: 640, height: 360), named: "clip", in: fixtures)
        try openInFinder(movie)
        waitForSizeToSettle(try playerWindow(for: movie))

        activate()
        app.typeKey(.escape, modifierFlags: [])

        XCTAssertTrue(
            app.wait(for: .runningBackground, timeout: 10),
            "Escape left the app on the screen"
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
