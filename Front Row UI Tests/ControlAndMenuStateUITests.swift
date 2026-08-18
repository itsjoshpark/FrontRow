//
//  ControlAndMenuStateUITests.swift
//  Front Row UI Tests
//

import XCTest

/// Menu items say what the player can do, and change when that changes.
///
/// Everything here is gated on `PlayEngine.isLoaded`, so these are the items that go wrong when
/// something clears the engine behind the interface's back.
final class ControlAndMenuStateUITests: FrontRowUITestCase {

    /// The Playback items `PlaybackCommands` disables until a file is loaded.
    private let gatedPlaybackItems = [
        "Restart", "Go Forward 5s", "Go Backward 5s", "Go to Time...", "Next Frame",
        "Previous Frame",
    ]

    /// Long enough that playback is still running when the menus are read - opening a menu and
    /// walking its items takes a second or two, and a short clip would reach its end first and
    /// make "Play" look like a bug.
    private let fixtureSeconds = 60

    func testPlaybackCommandsAreDisabledWithNothingOpen() throws {
        assertPlaybackItems(areEnabled: false)
        assertEqual(
            menus.states(of: "File", for: ["Show in Finder"])["Show in Finder"], false,
            "File ▸ Show in Finder"
        )
        assertEqual(
            menus.states(of: "Window", for: ["Natural Size"])["Natural Size"], false,
            "Window ▸ Natural Size"
        )
    }

    func testPlaybackCommandsAreEnabledOnceAFileIsOpen() async throws {
        try await openFixture(named: "clip")

        assertPlaybackItems(areEnabled: true)
        assertEqual(
            menus.states(of: "File", for: ["Show in Finder"])["Show in Finder"], true,
            "File ▸ Show in Finder"
        )
        assertEqual(
            menus.states(of: "Window", for: ["Natural Size"])["Natural Size"], true,
            "Window ▸ Natural Size"
        )
    }

    /// The item is titled for what it will do, so it reads "Pause" only while something is playing.
    func testPlayPauseItemFollowsWhetherAnythingIsPlaying() async throws {
        try await openFixture(named: "clip")

        XCTAssertTrue(
            menus.contains("Pause", in: "Playback"),
            "A file is playing, so Playback should offer Pause"
        )

        menus.click("Pause", in: "Playback")
        XCTAssertTrue(
            menus.contains("Play", in: "Playback"),
            "Playback was paused, so Playback should offer Play"
        )

        menus.click("Play", in: "Playback")
        XCTAssertTrue(
            menus.contains("Pause", in: "Playback"),
            "Playback was resumed, so Playback should offer Pause again"
        )
    }

    /// Opening a file while one is already open makes SwiftUI close and recycle the player window,
    /// which the app hears as a window closing. Whatever it does about that must not leave the
    /// commands describing a player with nothing in it.
    func testPlaybackCommandsSurviveOpeningASecondFile() async throws {
        try await openFixture(named: "first")
        try await openFixture(named: "second")

        assertPlaybackItems(areEnabled: true)
        assertEqual(
            menus.states(of: "File", for: ["Show in Finder"])["Show in Finder"], true,
            "File ▸ Show in Finder"
        )
        XCTAssertTrue(
            menus.contains("Pause", in: "Playback"),
            "The second file should still be playing"
        )
    }

    /// `33dde01`: SwiftUI's own scene item called itself "Show Window", never enabled, and took
    /// the keyboard shortcut with it. The app writes the item instead.
    func testInspectorItemIsNamedAndTogglesThePanel() async throws {
        try await openFixture(named: "clip")

        let window = menus.states(of: "Window", for: ["Show Window", "Show Inspector"])
        XCTAssertNil(
            window["Show Window"] ?? nil,
            "The Window menu is carrying SwiftUI's generated scene item again"
        )
        assertEqual(window["Show Inspector"], true, "Window ▸ Show Inspector")

        menus.click("Show Inspector", in: "Window")
        // The Inspector is a utility panel, and AppKit takes one off the screen whenever its app
        // is not the active one. Driving the menu does not make Front Row active, so without this
        // the panel is opened and then immediately hidden, and the window below is never found.
        activate()
        XCTAssertTrue(
            app.windows["Inspector"].waitForExistence(timeout: 20),
            "The Inspector window did not open"
        )
        XCTAssertTrue(
            menus.contains("Hide Inspector", in: "Window"),
            "With the Inspector open the item should offer to hide it"
        )

        menus.click("Hide Inspector", in: "Window")
        XCTAssertTrue(
            menus.contains("Show Inspector", in: "Window"),
            "With the Inspector closed the item should offer to show it again"
        )
    }

    // MARK: - Helpers

    private func openFixture(named name: String) async throws {
        let movie = try await MediaFixtures.makeMovie(
            size: CGSize(width: 640, height: 360),
            named: name,
            in: fixtures,
            seconds: fixtureSeconds,
            // Nothing here looks at the picture, and a long file at thirty frames a second costs
            // more to encode than the test saves by having one.
            frameRate: 2
        )
        try openInFinder(movie)
        waitForSizeToSettle(try playerWindow(for: movie))
    }

    private func assertPlaybackItems(
        areEnabled expected: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let states = menus.states(of: "Playback", for: gatedPlaybackItems)
        for item in gatedPlaybackItems {
            assertEqual(states[item], expected, "Playback ▸ \(item)", file: file, line: line)
        }
    }

    private func assertEqual(
        _ actual: Bool??,
        _ expected: Bool,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let state = actual, let state else {
            XCTFail("\(label) is missing from the menu", file: file, line: line)
            return
        }
        XCTAssertEqual(
            state, expected,
            "\(label) should be \(expected ? "enabled" : "disabled")",
            file: file, line: line
        )
    }
}
