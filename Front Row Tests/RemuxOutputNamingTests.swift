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

    /// Names with dots in them keep everything up to the real extension.
    @Test
    func onlyTheContainerExtensionIsReplaced() {
        let output = RemuxOutputNaming.outputURL(
            for: URL(fileURLWithPath: "/Movies/Film.2019.1080p.mkv")
        ) { _ in false }

        #expect(output.lastPathComponent == "Film.2019.1080p.mp4")
    }
}
