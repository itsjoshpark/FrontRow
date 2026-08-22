//
//  RemuxAlertTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

struct RemuxAlertTests {

    private let file = URL(fileURLWithPath: "/Movies/The Film.mkv")

    private func offer(dropping subtitles: [DroppedSubtitle]) -> RemuxOffer {
        let recipe = RemuxRecipe(
            videoIndex: 0,
            videoTag: "avc1",
            audio: [PlannedAudio(index: 1, codecName: "aac", channels: 2, transcodes: false)],
            subtitleIndices: [],
            droppedSubtitles: subtitles
        )
        return RemuxOffer(
            url: file,
            plan: .remux(recipe),
            duration: 3600,
            tools: FFmpegTools(
                ffmpeg: URL(filePath: "/opt/homebrew/bin/ffmpeg"),
                ffprobe: URL(filePath: "/opt/homebrew/bin/ffprobe")
            ),
            scene: .player
        )
    }

    /// The offer names the file and says nothing about codecs - whether audio is re-encoded on the
    /// way is Front Row's problem, not something to put to the user.
    @Test
    func theOfferNamesTheFileAndNothingElse() {
        let message = RemuxOfferAlert.message(for: offer(dropping: []))

        #expect(message == "“The Film.mkv” can be opened after it is converted.")
    }

    /// Losing the subtitles is the one surprise worth heading off.
    @Test
    func theSubtitleWarningIsAppendedOnlyWhenTracksAreDropped() {
        let dropped = RemuxOfferAlert.message(
            for: offer(dropping: [DroppedSubtitle(codecName: "hdmv_pgs_subtitle", language: "eng")])
        )

        #expect(dropped.hasSuffix("Subtitles will be dropped."))
        #expect(!RemuxOfferAlert.message(for: offer(dropping: [])).contains("Subtitles"))
    }

    /// One sentence covers a codec that can't be decoded and a file with nothing playable in it.
    /// It's the string the recent-file alert already uses, so it arrives already translated.
    @Test
    func anUnplayableFileGetsTheSharedMessage() {
        let message = UnplayableFileMessage.text(for: file, mayBeDamaged: false)

        #expect(message == "“The Film.mkv” isn't a format Front Row can play.")
        #expect(message == UnplayableFileMessage.text(for: file))
    }

    /// A file ffprobe couldn't read at all is a different problem from one it read and rejected,
    /// and the extra sentence is the only thing that says so.
    @Test
    func aProbeFailureAddsTheDamagedSentence() {
        let message = UnplayableFileMessage.text(for: file, mayBeDamaged: true)

        #expect(message.hasPrefix("“The Film.mkv” isn't a format Front Row can play."))
        #expect(message.hasSuffix("The file may be damaged or incomplete."))
        #expect(RemuxProblemAlert.mayBeDamaged(.probeFailed))
        #expect(!RemuxProblemAlert.mayBeDamaged(.unsupported))
    }

    /// Pointing someone at the ffmpeg formula page is no use if they have no way to install it,
    /// so the button follows whether Homebrew is there.
    @Test
    func theInstallButtonFollowsWhetherHomebrewIsInstalled() {
        #expect(
            RemuxProblemAlert.buttons(for: .toolsMissing(hasHomebrew: true))
                == [.installFFmpeg, .cancel]
        )
        #expect(
            RemuxProblemAlert.buttons(for: .toolsMissing(hasHomebrew: false))
                == [.installHomebrew, .cancel]
        )
    }

    /// Nothing can be done about a file Front Row can't decode, so there's only one way out.
    @Test
    func theRefusalsOfferOnlyOK() {
        #expect(RemuxProblemAlert.buttons(for: .unsupported) == [.ok])
        #expect(RemuxProblemAlert.buttons(for: .probeFailed) == [.ok])
    }

    /// A file that was merely somewhere slow must not be told it is damaged.
    @Test
    func aCheckThatTimedOutIsNotReportedAsADamagedFile() {
        #expect(RemuxProblemAlert.buttons(for: .checkTimedOut) == [.ok])
        #expect(RemuxProblemAlert.mayBeDamaged(.checkTimedOut) == false)
        #expect(RemuxProblemAlert.mayBeDamaged(.probeFailed))
    }

    /// A check the user stopped is a choice, not a failure, so it must raise nothing at all - and
    /// a deadline that passed is not the same as a file that couldn't be read.
    @Test
    func onlySomeUnfinishedChecksAreWorthAnAlert() {
        #expect(MediaConversion.problemReason(for: FFmpegError.cancelled) == nil)
        #expect(MediaConversion.problemReason(for: CancellationError()) == nil)
        #expect(MediaConversion.problemReason(for: FFmpegError.timedOut) == .checkTimedOut)
        #expect(
            MediaConversion.problemReason(for: FFmpegError.toolsMissing(hasHomebrew: true))
                == .toolsMissing(hasHomebrew: true)
        )
        #expect(
            MediaConversion.problemReason(for: FFmpegError.probeFailed(message: "eof"))
                == .probeFailed
        )
    }
}
