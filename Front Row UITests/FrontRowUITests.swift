//
//  FrontRowUITests.swift
//  Front Row UITests
//

import XCTest

/// Drives the real app through the surfaces a unit test can't reach: the window it opens on
/// launch, the menus it installs, and the sheet it presents.
///
/// These cover the paths where a view reads something out of the SwiftUI environment. Nothing
/// below asserts on how that wiring is done - only that the app can be driven through it without
/// falling over, which is exactly what breaks when an environment value isn't where a view
/// expects it.
@MainActor
final class FrontRowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Shadows what's on disk through the argument domain rather than writing to it, so the
        // welcome window starts in a known state and the suite leaves the recent files of
        // whoever ran it alone. Sparkle is silenced so an update check can't steal focus.
        app.launchArguments = [
            "-RecentDocuments", "",
            "-SUEnableAutomaticChecks", "NO",
        ]
        app.launch()
    }

    override func tearDown() async throws {
        app.terminate()
        app = nil
    }

    // MARK: - Welcome window

    func testWelcomeWindowAppearsOnLaunch() {
        XCTAssertTrue(
            welcomeWindow.waitForExistence(timeout: 10), "The welcome window should open on launch")
        XCTAssertTrue(welcomeWindow.staticTexts["Front Row"].exists)
    }

    func testWelcomeWindowOffersOpenFileAndOpenURL() {
        XCTAssertTrue(welcomeWindow.waitForExistence(timeout: 10))
        XCTAssertTrue(welcomeWindow.buttons["Open File..."].exists)
        XCTAssertTrue(welcomeWindow.buttons["Open URL..."].exists)
    }

    /// With the recent documents shadowed empty, the list says so and there is nothing to resume.
    func testWelcomeWindowSaysWhenThereAreNoRecentFiles() {
        XCTAssertTrue(welcomeWindow.waitForExistence(timeout: 10))
        XCTAssertTrue(welcomeWindow.staticTexts["No Recent Files"].exists)

        let resumeButtons = welcomeWindow.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Resume '"))
        XCTAssertEqual(resumeButtons.count, 0, "Nothing should be offered to resume")
    }

    /// The player window is suppressed at launch, so the welcome window is the only one up.
    func testPlayerWindowIsNotOpenAtLaunch() {
        XCTAssertTrue(welcomeWindow.waitForExistence(timeout: 10))
        XCTAssertFalse(app.windows["Front Row"].exists)
    }

    // MARK: - Open URL

    /// The sheet reads the play engine out of the environment. If the welcome scene didn't carry
    /// it, presenting this would bring the app down rather than show a field.
    func testOpenURLSheetPresentsFromTheWelcomeWindow() {
        XCTAssertTrue(welcomeWindow.waitForExistence(timeout: 10))

        welcomeWindow.buttons["Open URL..."].click()

        XCTAssertTrue(
            enterURLField.waitForExistence(timeout: 5),
            "The Open URL sheet should present with its text field")
        XCTAssertTrue(app.state == .runningForeground, "The app should still be running")
    }

    func testOpenURLSheetPresentsFromTheFileMenu() {
        XCTAssertTrue(welcomeWindow.waitForExistence(timeout: 10))

        fileMenu.click()
        fileMenu.menuItems["Open URL..."].click()

        XCTAssertTrue(enterURLField.waitForExistence(timeout: 5))
    }

    /// Typing something unparseable must be reported in place rather than dismissing or crashing.
    func testAnUnopenableURLLeavesTheSheetUp() {
        XCTAssertTrue(welcomeWindow.waitForExistence(timeout: 10))
        welcomeWindow.buttons["Open URL..."].click()
        XCTAssertTrue(enterURLField.waitForExistence(timeout: 5))

        enterURLField.click()
        enterURLField.typeText("not a url\n")

        XCTAssertTrue(enterURLField.exists, "The sheet should stay up after a failed open")
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: - Menu bar

    /// Everything that acts on a file is disabled until one is loaded.
    func testPlaybackCommandsAreDisabledWithNothingLoaded() {
        XCTAssertTrue(welcomeWindow.waitForExistence(timeout: 10))

        playbackMenu.click()

        XCTAssertTrue(playbackMenu.menuItems["Play"].waitForExistence(timeout: 5))

        // Existence is asserted first because `isEnabled` is also false for an item that isn't
        // there at all, which would let these pass without proving anything.
        for title in ["Play", "Restart", "Go to Time..."] {
            let item = playbackMenu.menuItems[title]
            XCTAssertTrue(item.exists, "\(title) should be in the Playback menu")
            XCTAssertFalse(item.isEnabled, "\(title) should be disabled with no file loaded")
        }
    }

    /// The skip interval picker is populated from SkipInterval, so every case has to show up.
    func testSkipIntervalOffersEveryInterval() {
        XCTAssertTrue(welcomeWindow.waitForExistence(timeout: 10))

        playbackMenu.click()
        let skipInterval = playbackMenu.menuItems["Skip Interval"]
        XCTAssertTrue(skipInterval.waitForExistence(timeout: 5))
        skipInterval.hover()

        for seconds in ["5s", "10s", "15s", "30s"] {
            XCTAssertTrue(
                skipInterval.menuItems[seconds].waitForExistence(timeout: 5),
                "\(seconds) should be offered as a skip interval")
        }
    }

    func testFileMenuOffersOpenRecentAndDisablesShowInFinder() {
        XCTAssertTrue(welcomeWindow.waitForExistence(timeout: 10))

        fileMenu.click()

        XCTAssertTrue(fileMenu.menuItems["Open Recent"].waitForExistence(timeout: 5))
        XCTAssertTrue(fileMenu.menuItems["Open File..."].exists)

        let showInFinder = fileMenu.menuItems["Show in Finder"]
        XCTAssertTrue(showInFinder.exists)
        XCTAssertFalse(showInFinder.isEnabled, "Nothing is playing, so there is nothing to show")
    }

    // MARK: - Elements

    private var welcomeWindow: XCUIElement {
        app.windows["Welcome to Front Row"]
    }

    private var enterURLField: XCUIElement {
        app.textFields.element(boundBy: 0)
    }

    private var fileMenu: XCUIElement {
        app.menuBars.menuBarItems["File"]
    }

    private var playbackMenu: XCUIElement {
        app.menuBars.menuBarItems["Playback"]
    }
}
