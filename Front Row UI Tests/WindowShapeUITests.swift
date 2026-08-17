//
//  WindowShapeUITests.swift
//  Front Row UI Tests
//

import XCTest

/// The player window's shape follows the video it is showing.
///
/// `WindowControllerTests` already pins `WindowController` in isolation. These drive the real app,
/// which is where the ordering between AVFoundation publishing a size, SwiftUI opening a window,
/// and AppKit applying the constraint actually plays out - and where this has regressed before.
final class WindowShapeUITests: FrontRowUITestCase {

    /// How far a window's shape may sit from the video's before it reads as the wrong shape.
    /// Loose enough for rounding, tight enough that 16:9 and 4:3 can never pass for each other.
    private let tolerance = 0.02

    func testWindowTakesTheShapeOfTheFirstVideo() async throws {
        let movie = try await MediaFixtures.makeMovie(
            size: CGSize(width: 640, height: 360), named: "landscape", in: fixtures)

        try openInFinder(movie)
        let window = try playerWindow(for: movie)
        let size = waitForSizeToSettle(window)

        assertShape(size, matches: CGSize(width: 640, height: 360), for: movie)
    }

    /// The regression behind `bd176af`, and the symptom that came back after it: the second file
    /// of a session is left in the first one's window.
    func testWindowTakesTheShapeOfASecondVideo() async throws {
        let landscape = try await MediaFixtures.makeMovie(
            size: CGSize(width: 640, height: 360), named: "landscape", in: fixtures)
        let portrait = try await MediaFixtures.makeMovie(
            size: CGSize(width: 480, height: 640), named: "portrait", in: fixtures)

        try openInFinder(landscape)
        waitForSizeToSettle(try playerWindow(for: landscape))

        try openInFinder(portrait)
        let window = try playerWindow(for: portrait)
        let size = waitForSizeToSettle(window)

        assertShape(size, matches: CGSize(width: 480, height: 640), for: portrait)
    }

    /// A third file, to catch a fit that recovers once rather than one that keeps up.
    func testWindowKeepsUpAcrossSeveralVideos() async throws {
        let sizes = [
            CGSize(width: 640, height: 360),
            CGSize(width: 320, height: 240),
            CGSize(width: 800, height: 200),
        ]

        for (index, videoSize) in sizes.enumerated() {
            let movie = try await MediaFixtures.makeMovie(
                size: videoSize, named: "clip\(index)", in: fixtures)

            try openInFinder(movie)
            let window = try playerWindow(for: movie)
            let size = waitForSizeToSettle(window)

            assertShape(size, matches: videoSize, for: movie)
        }
    }

    /// `videoSize` is cleared when the item is replaced so that an identically sized file still
    /// registers as a change to fit to. Two files of the same dimensions must both come out right.
    func testWindowIsStillCorrectForAFileOfIdenticalDimensions() async throws {
        let first = try await MediaFixtures.makeMovie(
            size: CGSize(width: 640, height: 360), named: "first", in: fixtures)
        let second = try await MediaFixtures.makeMovie(
            size: CGSize(width: 640, height: 360), named: "second", in: fixtures)

        try openInFinder(first)
        waitForSizeToSettle(try playerWindow(for: first))

        try openInFinder(second)
        let window = try playerWindow(for: second)
        let size = waitForSizeToSettle(window)

        assertShape(size, matches: CGSize(width: 640, height: 360), for: second)
    }

    /// Audio has no shape to hold the window to, so the constraint has to come off rather than
    /// keep the departed video's.
    func testAudioOnlyFileLeavesTheWindowFreeToResize() async throws {
        let movie = try await MediaFixtures.makeMovie(
            size: CGSize(width: 640, height: 360), named: "landscape", in: fixtures)
        let audio = try await MediaFixtures.makeAudioOnly(named: "song", in: fixtures)

        try openInFinder(movie)
        waitForSizeToSettle(try playerWindow(for: movie))

        try openInFinder(audio)
        let window = try playerWindow(for: audio)
        waitForSizeToSettle(window)

        let before = window.frame.size
        // Widening by a lot: a window still held to 16:9 would take back most of the height.
        window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .press(
                forDuration: 0.1,
                thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
                    .withOffset(CGVector(dx: 120, dy: 0))
            )
        let after = waitForSizeToSettle(window)

        XCTAssertEqual(
            after.height, before.height, accuracy: 4,
            "Widening an audio-only window changed its height, so an aspect ratio is still held"
        )
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
