//
//  RemuxOutputNamingTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

struct RemuxOutputNamingTests {

    private let input = URL(fileURLWithPath: "/Movies/The Film.mkv")

    @Test
    func theConvertedFileSitsBesideTheOriginal() {
        let output = RemuxOutputNaming.outputURL(for: input) { _ in false }

        #expect(output == URL(fileURLWithPath: "/Movies/The Film.mp4"))
    }

    /// Converting the same file twice must not quietly overwrite the first result.
    @Test
    func anExistingFileIsNumberedRatherThanReplaced() {
        let taken: Set<URL> = [URL(fileURLWithPath: "/Movies/The Film.mp4")]
        let output = RemuxOutputNaming.outputURL(for: input) { taken.contains($0) }

        #expect(output == URL(fileURLWithPath: "/Movies/The Film 2.mp4"))
    }

    @Test
    func numberingContinuesPastTheFirstCollision() {
        let taken: Set<URL> = [
            URL(fileURLWithPath: "/Movies/The Film.mp4"),
            URL(fileURLWithPath: "/Movies/The Film 2.mp4"),
            URL(fileURLWithPath: "/Movies/The Film 3.mp4"),
        ]
        let output = RemuxOutputNaming.outputURL(for: input) { taken.contains($0) }

        #expect(output == URL(fileURLWithPath: "/Movies/The Film 4.mp4"))
    }

    /// A file system that answers "yes, that exists" to everything must not send this spinning.
    @Test
    func anEndlessCollisionStillReturnsAName() {
        let output = RemuxOutputNaming.outputURL(for: input) { _ in true }

        #expect(output.pathExtension == "mp4")
        #expect(output.deletingLastPathComponent().path() == "/Movies/")
    }

    /// ffmpeg writes here, and the result is only renamed into place once it finishes — so this
    /// has to sit on the same volume to make that a rename, stay hidden while it is half a film,
    /// and keep the extension ffmpeg picks its muxer from.
    @Test
    func theWorkingFileIsHiddenBesideTheOutput() {
        let output = URL(fileURLWithPath: "/Movies/The Film.mp4")
        let working = RemuxOutputNaming.workingURL(besides: output)

        #expect(working.deletingLastPathComponent() == output.deletingLastPathComponent())
        #expect(working.lastPathComponent.hasPrefix("."))
        #expect(working.pathExtension == "mp4")
        #expect(working != output)
    }

    /// Two conversions running at once must not write to the same scratch path.
    @Test
    func everyWorkingFileIsDistinct() {
        let output = URL(fileURLWithPath: "/Movies/The Film.mp4")

        #expect(
            RemuxOutputNaming.workingURL(besides: output)
                != RemuxOutputNaming.workingURL(besides: output)
        )
    }

    /// Names with dots in them keep everything up to the real extension.
    @Test
    func onlyTheContainerExtensionIsReplaced() {
        let output = RemuxOutputNaming.outputURL(
            for: URL(fileURLWithPath: "/Movies/Film.2019.1080p.mkv")
        ) { _ in false }

        #expect(output.lastPathComponent == "Film.2019.1080p.mp4")
    }
}
