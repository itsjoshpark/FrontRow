//
//  FrontRowUITestCase.swift
//  Front Row UI Tests
//

import AppKit
import CoreGraphics
import XCTest

/// Shared setup for the UI tests: a fresh app per test, an English interface, and somewhere to
/// put the fixtures.
///
/// The app is matched by bundle identifier rather than by the scheme's test target, so the tests
/// say out loud which app they drive.
@MainActor
class FrontRowUITestCase: XCTestCase {

    static let bundleIdentifier = "dev.joshuapark.FrontRow"

    private(set) var app: XCUIApplication!
    private(set) var fixtures: URL!

    /// Defaults the app writes that a test run would otherwise leave behind.
    ///
    /// The app reads `UserDefaults.standard`, and the argument domain only shadows reads - what it
    /// writes still lands in the real preferences. Left alone, a run fills the user's Open Recent
    /// menu with fixtures that were deleted when the run ended.
    private static let ownedDefaultsKeys = ["RecentDocuments", "SkipInterval", "ShowTimeRemaining"]

    private var savedDefaults: [String: Any] = [:]

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false

        takeOverDefaults()
        fixtures = try MediaFixtures.makeDirectory()

        app = XCUIApplication(bundleIdentifier: Self.bundleIdentifier)
        stopRunningApp()
        try startApp()
    }

    /// Starts the app through Launch Services and waits for its first window.
    ///
    /// A scene is only presented for its `defaultLaunchBehavior` on a launch Launch Services calls
    /// a default one, so the app has to be opened the way the Dock opens it. The test then drives
    /// the running process.
    private func startApp() throws {
        // The tests match the English strings in Localizable.xcstrings, so the interface has to be
        // in English whatever the machine is set to.
        let status = run(
            "/usr/bin/open",
            [
                try applicationURL.path(percentEncoded: false),
                "--args", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            ]
        )
        XCTAssertEqual(status, 0, "`open` would not start the app")

        // `open` returns as soon as the request is made.
        XCTAssertTrue(
            app.windows.firstMatch.waitForExistence(timeout: 30),
            "The app came up with no window.\(Self.sessionAdvice)"
        )
    }

    /// Why a window might be missing for a reason that is nothing to do with the app.
    ///
    /// A SwiftUI scene needs a window server to be drawn into. On a locked or sleeping display
    /// there isn't one, so the app launches, reaches its event loop and stays there with no window
    /// - which reads from here as the app failing to open one. Every test in this bundle fails the
    /// same way, in setup, which is a confusing thing to wake up to.
    private static var sessionAdvice: String {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else {
            return " There is no window server session - UI tests need one, so unlock the screen."
        }
        let onConsole = session["kCGSSessionOnConsoleKey"] as? Bool ?? false
        let locked = session["CGSSessionScreenIsLocked"] as? Bool ?? false
        guard onConsole, !locked else {
            return " The screen is locked or this session is not the console one - "
                + "UI tests need an unlocked display."
        }
        return ""
    }

    override func tearDown() async throws {
        stopRunningApp()
        app = nil

        restoreDefaults()

        if let fixtures {
            try? FileManager.default.removeItem(at: fixtures)
        }
        fixtures = nil

        try await super.tearDown()
    }

    /// Brings the app to the front and waits until it is there.
    ///
    /// Synthesising a click into a menu drives the app without making it the active one, and a
    /// utility panel is only on the screen while its app is active. A test that reads one has to
    /// say which app is in front rather than assume it is still the one it launched.
    func activate(timeout: TimeInterval = 10) {
        app.activate()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: timeout),
            "The app did not come to the front"
        )
    }

    /// Quits and starts the app again, keeping whatever it persisted.
    ///
    /// Used where the case under test only shows on a fresh start - the welcome window and its
    /// list of recent files are only drawn when nothing is open.
    func relaunchApp() throws {
        stopRunningApp()
        try startApp()
    }

    /// Kills every copy of the app and waits for the processes to actually be gone.
    ///
    /// A copy that outlives its test matters: `open` hands the next test's file to whichever copy
    /// Launch Services picks, and a test watching a different one waits out its timeout for a
    /// window that opened somewhere else.
    private func stopRunningApp() {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            let running = NSRunningApplication.runningApplications(
                withBundleIdentifier: Self.bundleIdentifier)
            guard !running.isEmpty else { return }
            for application in running { application.forceTerminate() }
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTFail("A copy of the app would not go away")
    }

    /// Runs `tool` and returns its exit status, with output discarded.
    private func run(_ tool: String, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(filePath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }

    /// Empties the defaults the app writes, remembering what was there.
    private func takeOverDefaults() {
        guard let defaults = UserDefaults(suiteName: Self.bundleIdentifier) else { return }
        savedDefaults = [:]
        for key in Self.ownedDefaultsKeys {
            if let value = defaults.object(forKey: key) {
                savedDefaults[key] = value
            }
            defaults.removeObject(forKey: key)
        }
    }

    private func restoreDefaults() {
        guard let defaults = UserDefaults(suiteName: Self.bundleIdentifier) else { return }
        for key in Self.ownedDefaultsKeys {
            if let value = savedDefaults[key] {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        savedDefaults = [:]
    }

    // MARK: - Opening files

    /// The built `Front Row.app`, found next to the test bundle in the products directory.
    ///
    /// Located by path rather than by asking LaunchServices for the bundle identifier, which could
    /// answer with an installed release copy instead of the build under test.
    var applicationURL: URL {
        get throws {
            var directory = Bundle(for: Self.self).bundleURL
            while directory.pathComponents.count > 1 {
                let candidate = directory.appending(path: "Front Row.app")
                if FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
                    return candidate
                }
                directory = directory.deletingLastPathComponent()
            }
            throw UITestError.applicationNotFound
        }
    }

    /// Opens `url` the way double-clicking it in the Finder does, through
    /// `AppDelegate.application(_:open:)`.
    ///
    /// The routes a user can take are `FileOpeningUITests`' subject. Everything else needs a file
    /// open without the route being the point, and this is the least breakable way to get one.
    func openInFinder(_ url: URL) throws {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/open")
        process.arguments = [
            "-a", try applicationURL.path(percentEncoded: false), url.path(percentEncoded: false),
        ]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, "`open` failed for \(url.lastPathComponent)")
    }

    // MARK: - Waiting

    /// The player window showing `fileName`, once it exists.
    func playerWindow(for fileURL: URL, timeout: TimeInterval = 20) throws -> XCUIElement {
        let window = app.windows[fileURL.lastPathComponent]
        XCTAssertTrue(
            window.waitForExistence(timeout: timeout),
            "No player window titled \(fileURL.lastPathComponent) appeared"
        )
        return window
    }

    /// Waits for `window`'s size to stop changing, so an assertion doesn't race the resize.
    ///
    /// The window is shaped a little after the file opens - AVFoundation publishes the video's
    /// size asynchronously - so there is no single event to wait on. Settling is the honest
    /// condition, and a test that asserts before it has landed would pass or fail on timing.
    ///
    /// Pass `previousSize` where the window is already up and being reshaped for a second file:
    /// it is retitled before the new size arrives, so settling alone would answer with the size
    /// it is being resized away from.
    @discardableResult
    func waitForSizeToSettle(
        _ window: XCUIElement,
        changingFrom previousSize: CGSize? = nil,
        stableFor: TimeInterval = 1.0,
        timeout: TimeInterval = 15,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> CGSize {
        let deadline = Date().addingTimeInterval(timeout)
        var lastSize = window.frame.size
        var stableSince = Date()
        var hasResized = previousSize.map { $0 != lastSize } ?? true

        while Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
            let size = window.frame.size
            if size != lastSize {
                lastSize = size
                stableSince = Date()
                hasResized = true
                continue
            }
            if hasResized, Date().timeIntervalSince(stableSince) >= stableFor {
                return size
            }
        }

        XCTFail(
            """
            \(window.title) \(hasResized ? "would not stop resizing" : "never resized") \
            in \(timeout)s, and is \(Int(lastSize.width))x\(Int(lastSize.height)).
            """,
            file: file,
            line: line
        )
        return lastSize
    }

    enum UITestError: Error {
        case applicationNotFound
    }
}

extension CGSize {
    /// Width over height, for comparing a window's shape against a video's.
    var aspectRatio: CGFloat { height == 0 ? 0 : width / height }
}
