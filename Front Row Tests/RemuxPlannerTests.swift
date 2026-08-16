//
//  RemuxPlannerTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

struct RemuxPlannerTests {

    private func video(
        _ index: Int = 0,
        _ codec: String,
        pixelFormat: String? = "yuv420p",
        profile: String? = nil,
        attachedPic: Bool = false
    ) -> ProbedStream {
        ProbedStream(
            index: index,
            kind: .video,
            codecName: codec,
            profile: profile,
            pixelFormat: pixelFormat,
            disposition: ProbedStream.Disposition(attachedPic: attachedPic ? 1 : 0)
        )
    }

    private func audio(_ index: Int, _ codec: String, channels: Int? = 2) -> ProbedStream {
        ProbedStream(index: index, kind: .audio, codecName: codec, channels: channels)
    }

    private func subtitle(_ index: Int, _ codec: String, language: String? = nil) -> ProbedStream {
        ProbedStream(
            index: index,
            kind: .subtitle,
            codecName: codec,
            tags: ProbedStream.Tags(language: language)
        )
    }

    /// The case the whole feature exists for: everything copies, so nothing is re-encoded.
    @Test
    func h264WithAACIsALosslessRemux() {
        let plan = RemuxPlanner.plan(for: [video(0, "h264"), audio(1, "aac")])

        guard case .remux(let recipe) = plan else {
            Issue.record("expected a lossless remux, got \(plan)")
            return
        }
        #expect(recipe.videoIndex == 0)
        #expect(recipe.videoTag == "avc1")
        #expect(
            recipe.audio == [
                PlannedAudio(index: 1, codecName: "aac", channels: 2, transcodes: false)
            ])
        #expect(!recipe.transcodesAudio)
    }

    /// Without the right `-tag:v`, MP4 records HEVC as `hev1` and AVFoundation refuses the file -
    /// a conversion that reports success and then won't open.
    @Test
    func eachCodecGetsTheTagAVFoundationExpects() {
        #expect(RemuxPlanner.videoTag(for: "hevc") == "hvc1")
        #expect(RemuxPlanner.videoTag(for: "h264") == "avc1")
        #expect(RemuxPlanner.videoTag(for: "av1") == "av01")
        #expect(RemuxPlanner.videoTag(for: "prores") == nil)
    }

    /// 10-bit HEVC is the HDR case Front Row exists to play, so it must stay on the copyable side
    /// of the pixel-format check.
    @Test
    func tenBitHEVCIsCopyable() {
        let plan = RemuxPlanner.plan(for: [
            video(0, "hevc", pixelFormat: "yuv420p10le", profile: "Main 10"), audio(1, "eac3"),
        ])

        #expect(plan.recipe?.videoTag == "hvc1")
        #expect(plan.recipe?.transcodesAudio == false)
    }

    /// VideoToolbox has no 10-bit H.264 decoder, unlike its HEVC one. Remuxing these would produce
    /// a file that opens to a black frame.
    @Test
    func tenBitH264IsRefused() {
        let plan = RemuxPlanner.plan(for: [
            video(0, "h264", pixelFormat: "yuv420p10le", profile: "High 10"), audio(1, "aac"),
        ])

        #expect(plan == .unsupported(.video(codec: "h264")))
    }

    /// 4:2:2 and 4:4:4 don't decode whatever the codec, and the check has to work off the profile
    /// for files where ffprobe reports no pixel format.
    @Test
    func highChromaIsRefusedFromEitherThePixelFormatOrTheProfile() {
        let byPixelFormat = RemuxPlanner.plan(for: [video(0, "h264", pixelFormat: "yuv444p")])
        #expect(byPixelFormat == .unsupported(.video(codec: "h264")))

        let byProfile = RemuxPlanner.plan(for: [
            video(0, "h264", pixelFormat: nil, profile: "High 4:2:2")
        ])
        #expect(byProfile == .unsupported(.video(codec: "h264")))
    }

    /// VideoToolbox has no software AV1 decoder, so on a Mac without the hardware an AV1 MP4 won't
    /// open however cleanly ffmpeg wrote it - the exact "converts fine, then won't play" outcome
    /// this table exists to prevent.
    @Test
    func av1FollowsWhetherThisMacCanDecodeIt() {
        let streams = [video(0, "av1", pixelFormat: "yuv420p"), audio(1, "aac")]

        #expect(
            RemuxPlanner.plan(for: streams, canDecodeAV1: false)
                == .unsupported(.video(codec: "av1"))
        )
        #expect(RemuxPlanner.plan(for: streams, canDecodeAV1: true).recipe?.videoTag == "av01")
    }

    /// A container swap can't help a codec AVFoundation can't decode, so it must not be offered.
    @Test
    func vp9IsRefusedRatherThanRemuxed() {
        let plan = RemuxPlanner.plan(for: [video(0, "vp9"), audio(1, "opus")])

        #expect(plan == .unsupported(.video(codec: "vp9")))
    }

    /// Unsupported audio alone is no reason to give up: the video still copies.
    @Test
    func dtsAudioIsTranscodedWhileTheVideoIsCopied() {
        let plan = RemuxPlanner.plan(for: [video(0, "hevc"), audio(1, "dts", channels: 6)])

        guard case .transcodingAudio(let recipe) = plan else {
            Issue.record("expected an audio transcode, got \(plan)")
            return
        }
        #expect(recipe.videoIndex == 0)
        #expect(recipe.firstTranscodedAudio?.codecName == "dts")
        #expect(recipe.firstTranscodedAudio?.channels == 6)
    }

    /// A perfectly good AAC track shouldn't be re-encoded just because a DTS track sits next to it.
    @Test
    func onlyTheUnsupportedTrackIsTranscoded() {
        let plan = RemuxPlanner.plan(for: [
            video(0, "h264"), audio(1, "aac"), audio(2, "truehd", channels: 8),
        ])

        #expect(plan.recipe?.audio.map(\.transcodes) == [false, true])
    }

    /// Text subtitles survive as `mov_text`; bitmap ones can't be stored in an MP4 at all and have
    /// to be reported so the dialog can say what's being lost.
    @Test
    func textSubtitlesAreKeptAndBitmapOnesAreReported() {
        let plan = RemuxPlanner.plan(for: [
            video(0, "h264"),
            audio(1, "aac"),
            subtitle(2, "subrip", language: "eng"),
            subtitle(3, "hdmv_pgs_subtitle", language: "fra"),
        ])

        #expect(plan.recipe?.subtitleIndices == [2])
        #expect(
            plan.recipe?.droppedSubtitles == [
                DroppedSubtitle(codecName: "hdmv_pgs_subtitle", language: "fra")
            ]
        )
    }

    /// Cover art is reported as a video stream. Treating it as the video track would produce a
    /// file that shows one still image for its whole length.
    @Test
    func coverArtIsNotMistakenForTheVideoTrack() {
        let plan = RemuxPlanner.plan(for: [
            video(0, "mjpeg", attachedPic: true), audio(1, "flac"),
        ])

        #expect(plan.recipe?.videoIndex == nil)
        #expect(plan.recipe?.audio.count == 1)
    }

    /// Nothing to play means nothing to offer.
    @Test
    func aFileWithNoVideoOrAudioIsRefused() {
        let plan = RemuxPlanner.plan(for: [subtitle(0, "subrip")])

        #expect(plan == .unsupported(.noPlayableStreams))
    }
}
