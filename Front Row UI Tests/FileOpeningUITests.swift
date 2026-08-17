//
//  FileOpeningUITests.swift
//  Front Row UI Tests
//

import XCTest

/// The ways a file gets into the player.
///
/// Every route ends at `openFileAndPresent(url:)`, so what differs between them is the interface
/// in front of it - a panel, a sheet, a drop, or a Finder double-click - and each has broken on
/// its own before.
final class FileOpeningUITests: FrontRowUITestCase {

    // MARK: - The routes

    func testOpeningThroughTheOpenPanel() async throws {
        let movie = try await makeClip(named: "panel")

        // Brought to the front first. `presentOpenFilePanel` sheets the panel onto the main
        // window, and an app that isn't active has none - the panel then opens as a window of its
        // own, and closing it takes the app with it.
        app.activate()

        // The keyboard shortcut rather than the menu item: clicking File ▸ Open File… lands while
        // the menu is still tracking and the panel never opens.
        app.typeKey("o", modifierFlags: .command)

        let panel = app.descendants(matching: .any)["open-panel"]
        XCTAssertTrue(
            panel.waitForExistence(timeout: 20),
            """
            No Open panel appeared for ⌘O. \
            Windows: \(app.windows.allElementsBoundByIndex.map(\.identifier)).
            """
        )
        typePath(movie)

        try assertPlaying(movie)
    }

    func testOpeningThroughTheOpenURLSheet() async throws {
        let movie = try await makeClip(named: "sheet")

        app.typeKey("o", modifierFlags: [.command, .shift])
        let field = app.sheets.firstMatch.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 15), "The Open URL sheet did not appear")

        app.typeText(movie.absoluteString)
        app.typeKey(.return, modifierFlags: [])

        try assertPlaying(movie)
    }

    /// A URL that leads nowhere flags the field and keeps the sheet up, rather than closing as
    /// though it worked.
    func testOpenURLSheetKeepsItselfUpForAUrlThatWontOpen() throws {
        app.typeKey("o", modifierFlags: [.command, .shift])
        let field = app.sheets.firstMatch.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 15), "The Open URL sheet did not appear")

        app.typeText("file:///nowhere/at/all.mp4")
        app.typeKey(.return, modifierFlags: [])
        Thread.sleep(forTimeInterval: 3)

        XCTAssertTrue(
            app.sheets.firstMatch.exists,
            "The Open URL sheet closed even though nothing opened"
        )
    }

    /// Opening the app *with* a file, the way double-clicking one in the Finder does. This skips
    /// the welcome window, which is the case `MediaConversion.hostScene()` works around.
    func testOpeningAFileGoesStraightToThePlayer() async throws {
        let movie = try await makeClip(named: "finder")

        try openInFinder(movie)

        try assertPlaying(movie)
        XCTAssertFalse(
            app.windows["welcome"].exists,
            "The welcome window is still up behind the player"
        )
    }

    // MARK: - Recent documents

    /// `442992a`: the alert was gated on the window being key, which presenting it takes away - so
    /// clicking a recent file that had gone did nothing at all.
    func testAMissingRecentFileExplainsItself() async throws {
        let movie = try await makeClip(named: "vanishing")
        try openInFinder(movie)
        try assertPlaying(movie)

        try FileManager.default.removeItem(at: movie)

        // Started again so the welcome window is drawn, which is where the recent file can be
        // clicked directly. The same entry sits in File ▸ Open Recent, but reaching into a
        // submenu is the flakiest thing XCUITest does.
        relaunchApp()
        let welcome = app.windows["welcome"]
        XCTAssertTrue(
            welcome.waitForExistence(timeout: 20),
            """
            The welcome window did not come back. \
            Windows: \(app.windows.allElementsBoundByIndex.map { "\($0.identifier)/\($0.title)" }).
            """
        )

        let entry = welcome.buttons[movie.lastPathComponent].firstMatch
        XCTAssertTrue(
            entry.waitForExistence(timeout: 20),
            """
            \(movie.lastPathComponent) is not listed on the welcome window. \
            Buttons: \(welcome.buttons.allElementsBoundByIndex.map(\.label)).
            """
        )
        entry.click()

        let explanation = app.staticTexts.containing(
            NSPredicate(format: "value CONTAINS %@", "moved or deleted")
        ).firstMatch
        XCTAssertTrue(
            explanation.waitForExistence(timeout: 20),
            "Clicking a recent file that is no longer there said nothing at all"
        )
    }

    // MARK: - Helpers

    private func makeClip(named name: String) async throws -> URL {
        try await MediaFixtures.makeMovie(
            size: CGSize(width: 640, height: 360),
            named: name,
            in: fixtures,
            seconds: 30,
            frameRate: 2
        )
    }

    /// Drives the Open panel's "Go to the folder" field, which is the only way to reach a
    /// temporary directory without clicking through the column browser.
    private func typePath(_ url: URL) {
        app.typeKey("g", modifierFlags: [.command, .shift])
        Thread.sleep(forTimeInterval: 1)
        app.typeText(url.path(percentEncoded: false))
        app.typeKey(.return, modifierFlags: [])
        Thread.sleep(forTimeInterval: 1.5)
        app.typeKey(.return, modifierFlags: [])
    }

    private func assertPlaying(
        _ url: URL,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let window = app.windows[url.lastPathComponent]
        XCTAssertTrue(
            window.waitForExistence(timeout: 20),
            "\(url.lastPathComponent) never reached the player",
            file: file,
            line: line
        )
        XCTAssertTrue(
            menus.contains("Pause", in: "Playback"),
            "\(url.lastPathComponent) opened but is not playing",
            file: file,
            line: line
        )
    }

}
