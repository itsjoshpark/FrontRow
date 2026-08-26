//
//  ConversionUITests.swift
//  Front Row UI Tests
//

import XCTest

/// What the user sees when a Matroska file is handed to the app.
///
/// The conversion asks a question and then runs behind a sheet, so unlike every other way a file
/// opens there is a stretch with nothing playing. Which window that stretch is shown in is the
/// subject here; whether the conversion itself produces a playable file is the unit tests'.
final class ConversionUITests: FrontRowUITestCase {

    /// Homebrew on Apple Silicon, Homebrew on Intel, then MacPorts - the same list the app
    /// searches. Repeated rather than shared because the UI tests drive the app from outside and
    /// cannot import it.
    private static let toolSearchPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/opt/local/bin"]

    /// Handing the app a Matroska file opens the player window whether the app asks for one or not
    /// - macOS presents it along with the file - and the welcome window has to give way to it, as
    /// it does for a file that just plays. Left up, it sits beside a blank player window that is
    /// holding the conversion's alert and progress sheet.
    func testConvertingAFileDoesNotLeaveTheWelcomeWindowBehind() throws {
        let matroska = try makeMatroska(named: "welcome-behind")

        try openInFinder(matroska)

        let convert = app.buttons["Convert"]
        XCTAssertTrue(
            convert.waitForExistence(timeout: 60),
            """
            No offer to convert \(matroska.lastPathComponent) appeared. \
            Windows: \(app.windows.allElementsBoundByIndex.map { "\($0.identifier)/\($0.title)" }).
            """
        )
        XCTAssertFalse(
            app.windows["welcome"].exists,
            "The welcome window is still up beside the window holding the conversion alert"
        )
    }

    // MARK: - Helpers

    /// A one-second Matroska file of H.264 video and FLAC audio.
    ///
    /// Written by ffmpeg rather than committed: nothing else on the machine can write Matroska, and
    /// a test that needs ffmpeg installed to reach the conversion at all has no use for a fixture
    /// that exists to avoid needing it. FLAC copies into an MP4 untouched, so the offer alert
    /// describes a straight remux.
    private func makeMatroska(named name: String) throws -> URL {
        guard let ffmpeg = locateTool("ffmpeg") else {
            throw XCTSkip("ffmpeg is not installed, so the app has no conversion to offer")
        }
        let url = fixtures.appending(path: "\(name).mkv")

        let process = Process()
        process.executableURL = ffmpeg
        process.arguments = [
            "-nostdin", "-loglevel", "error", "-y",
            "-f", "lavfi", "-i", "testsrc=size=320x180:rate=10:duration=1",
            "-f", "lavfi", "-i", "sine=frequency=440:duration=1",
            "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "flac",
            url.path(percentEncoded: false),
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, "ffmpeg would not write the fixture")

        return url
    }

    private func locateTool(_ name: String) -> URL? {
        Self.toolSearchPaths
            .map { URL(filePath: $0).appending(path: name) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path(percentEncoded: false)) }
    }
}
