//
//  WindowShapeUITests.swift
//  Front Row UI Tests
//

import XCTest

/// The player window's shape follows the video it is showing.
///
/// `WindowControllerTests` and `VideoWindowLayoutTests` already pin the sizing rules in
/// isolation. These drive the real app, which is where the ordering between AVFoundation
/// publishing a size, SwiftUI opening a window, and AppKit applying the constraint actually plays
/// out - and where this has regressed before.
final class WindowShapeUITests: FrontRowUITestCase {

    /// How far a window's shape may sit from the video's before it reads as the wrong shape.
    /// Loose enough for rounding, tight enough that 16:9 and 4:3 can never pass for each other.
    private let tolerance = 0.02

    private let landscape = CGSize(width: 640, height: 360)
    private let portrait = CGSize(width: 480, height: 640)

    func testWindowTakesTheShapeOfALandscapeVideo() async throws {
        try await assertWindowTakesTheShape(of: landscape, named: "landscape")
    }

    func testWindowTakesTheShapeOfAPortraitVideo() async throws {
        try await assertWindowTakesTheShape(of: portrait, named: "portrait")
    }

    /// The regression behind `bd176af`, and the symptom that came back after it: the second file
    /// of a session is left in the first one's window.
    func testWindowTakesTheShapeOfASecondVideo() async throws {
        let first = try await MediaFixtures.makeMovie(
            size: landscape, named: "landscape", in: fixtures)
        let second = try await MediaFixtures.makeMovie(
            size: portrait, named: "portrait", in: fixtures)

        try openInFinder(first)
        waitForSizeToSettle(try playerWindow(for: first))

        try openInFinder(second)
        let window = try playerWindow(for: second)
        let size = waitForSizeToSettle(window)

        assertShape(size, matches: portrait, for: second)
    }

    // MARK: - Helpers

    private func assertWindowTakesTheShape(of videoSize: CGSize, named name: String) async throws {
        let movie = try await MediaFixtures.makeMovie(
            size: videoSize, named: name, in: fixtures)

        try openInFinder(movie)
        let window = try playerWindow(for: movie)
        let size = waitForSizeToSettle(window)

        assertShape(size, matches: videoSize, for: movie)
    }

    private func assertShape(
        _ windowSize: CGSize,
        matches videoSize: CGSize,
        for url: URL,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            windowSize.aspectRatio,
            videoSize.aspectRatio,
            accuracy: tolerance,
            """
            \(url.lastPathComponent) is \(Int(videoSize.width))x\(Int(videoSize.height)) \
            (\(videoSize.aspectRatio)), but its window is \
            \(Int(windowSize.width))x\(Int(windowSize.height)) (\(windowSize.aspectRatio)).
            """,
            file: file,
            line: line
        )
    }
}
