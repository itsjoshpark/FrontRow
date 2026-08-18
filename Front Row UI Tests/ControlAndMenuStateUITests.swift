//
//  ControlAndMenuStateUITests.swift
//  Front Row UI Tests
//

import XCTest

/// The controls say what the player can do, and change when that changes.
///
/// Everything here is gated on `PlayEngine.isLoaded`, so these are the items that go wrong when
/// something clears the engine behind the interface's back.
final class ControlAndMenuStateUITests: FrontRowUITestCase {

    /// The Playback items `PlaybackCommands` disables until a file is loaded.
    private let gatedPlaybackItems = [
        "Restart", "Go Forward 5s", "Go Backward 5s", "Go to Time...", "Next Frame",
        "Previous Frame",
    ]

    /// The controls along the bottom of the player, which `PlayerControls` disables until a file
    /// is loaded.
    private let onScreenControls = ["play-pause", "skip-backward", "skip-forward"]

    /// Long enough that playback is still running when the controls are read - opening a menu and
    /// walking its items takes a second or two, and a short clip would reach its end first and
    /// make "Play" look like a bug.
    private let fixtureSeconds = 60

    // MARK: - Menu items

    /// There is no player window to read with nothing open - the main scene's launch behaviour is
    /// suppressed until a file is on its way - so the empty case is the menu's to answer.
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

    // MARK: - On-screen controls

    func testOnScreenControlsAreEnabledOnceAFileIsOpen() async throws {
        let window = try await openFixture(named: "clip")
        showControls(in: window)

        for identifier in onScreenControls {
            let button = window.buttons[identifier]
            XCTAssertTrue(
                button.waitForExistence(timeout: 10),
                """
                The player has no \(identifier) control. \
                Buttons: \(window.buttons.allElementsBoundByIndex.map(\.identifier)).
                """
            )
            XCTAssertTrue(button.isEnabled, "\(identifier) is disabled with a file open")
        }

        let slider = window.sliders["seek-slider"]
        XCTAssertTrue(
            slider.waitForExistence(timeout: 10),
            "The player has no seek-slider control"
        )
        XCTAssertTrue(slider.isEnabled, "seek-slider is disabled with a file open")
    }

    // MARK: - Helpers

    @discardableResult
    private func openFixture(named name: String) async throws -> XCUIElement {
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
        let window = try playerWindow(for: movie)
        waitForSizeToSettle(window)
        return window
    }

    /// Brings the control bar back after `PlayerChromeVisibility` has faded it.
    ///
    /// The bar goes to nothing three seconds after the mouse stops, and encoding a fixture takes
    /// longer than that. Hovering over the window is what the app hears as the mouse moving, so
    /// it is also what puts the controls back. The assertions read `isEnabled` rather than
    /// hittability so a fade that beats them cannot decide the result either way.
    private func showControls(in window: XCUIElement) {
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).hover()
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
