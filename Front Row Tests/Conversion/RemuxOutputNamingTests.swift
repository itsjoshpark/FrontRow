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

    /// ffmpeg writes here, and the result is only renamed into place once it finishes — so this has
    /// to sit on the same volume to make that a rename. Visible, so a run the app never got to tidy
    /// up leaves something the user can find and throw away rather than a hidden file they will
    /// never see; and `.part` so a half film cannot be double-clicked into a truncated one.
    @Test
    func theWorkingFileIsVisibleBesideTheOutputAndCannotBePlayed() {
        let output = URL(fileURLWithPath: "/Movies/The Film.mp4")
        let working = RemuxOutputNaming.workingURL(besides: output)

        #expect(working.deletingLastPathComponent() == output.deletingLastPathComponent())
        #expect(!working.lastPathComponent.hasPrefix("."))
        #expect(working.lastPathComponent == "The Film.mp4.part")
        #expect(working != output)
    }

    /// The working file follows whatever name the output ended up with, numbering included.
    @Test
    func theWorkingFileFollowsANumberedOutput() {
        let output = URL(fileURLWithPath: "/Movies/The Film 2.mp4")

        #expect(
            RemuxOutputNaming.workingURL(besides: output).lastPathComponent
                == "The Film 2.mp4.part"
        )
    }

    /// A working file left by a run that died holds its name against the next one.
    ///
    /// It is the user's to look at and delete now that they can see it, so a retry must not write
    /// over it — and this is also what keeps two conversions of the same file apart, since the
    /// first one's output does not exist yet while it is running but its working file does.
    @Test
    func aWorkingFileLeftBehindHoldsTheNameItWasFor() {
        let output = RemuxOutputNaming.outputURL(for: input) {
            $0.lastPathComponent == "The Film.mp4.part"
        }

        #expect(output.lastPathComponent == "The Film 2.mp4")
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
