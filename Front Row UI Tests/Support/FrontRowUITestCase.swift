//
//  FrontRowUITestCase.swift
//  Front Row UI Tests
//

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
        // A copy left over from the previous test - its own or one `open` started - answers
        // queries for a moment and then quits under the next test.
        stopRunningApp()
        // Matched against the English strings in Localizable.xcstrings rather than accessibility
        // identifiers, so the interface has to be in English whatever the machine is set to.
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Waited for rather than assumed. `launch()` returns as soon as the process is up, and a
        // test that starts driving menus before a window exists is testing the launch.
        XCTAssertTrue(
            app.windows.firstMatch.waitForExistence(timeout: 30),
            "The app came up with no window"
        )
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

    /// Quits and starts the app again, keeping whatever it persisted.
    ///
    /// Used where the case under test only shows on a fresh start - the welcome window and its
    /// list of recent files are only drawn when nothing is open.
    func relaunchApp() {
        stopRunningApp()
        app.launch()
    }

    /// Kills any copy of the app and waits for the process to actually be gone.
    ///
    /// Signalled rather than asked. `XCUIApplication.terminate()` waits for a graceful quit, and a
    /// test that leaves a sheet up never gets one - the run then hangs in teardown rather than
    /// failing. Nothing here needs the app to shut down tidily.
    private func stopRunningApp() {
        guard let executable = try? applicationURL.appending(path: "Contents/MacOS/Front Row")
        else {
            return
        }
        let path = executable.path(percentEncoded: false)

        run("/usr/bin/pkill", ["-f", path])

        let deadline = Date().addingTimeInterval(10)
        while run("/usr/bin/pgrep", ["-f", path]) == 0, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    /// Runs `tool` and returns its exit status, with output discarded.
    @discardableResult
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
    @discardableResult
    func waitForSizeToSettle(
        _ window: XCUIElement,
        stableFor: TimeInterval = 1.0,
        timeout: TimeInterval = 15
    ) -> CGSize {
        let deadline = Date().addingTimeInterval(timeout)
        var lastSize = window.frame.size
        var stableSince = Date()

        while Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
            let size = window.frame.size
            if size != lastSize {
                lastSize = size
                stableSince = Date()
                continue
            }
            if Date().timeIntervalSince(stableSince) >= stableFor {
                return size
            }
        }
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
