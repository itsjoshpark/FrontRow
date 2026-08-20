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

    /// 4:2:2 and 4:4:4 don't decode, whatever the codec and whatever its profile claims.
    @Test
    func highChromaIsRefused() {
        #expect(
            RemuxPlanner.plan(for: [video(0, "h264", pixelFormat: "yuv444p")])
                == .unsupported(.video(codec: "h264"))
        )
        #expect(
            RemuxPlanner.plan(for: [video(0, "hevc", pixelFormat: "yuv422p10le")])
                == .unsupported(.video(codec: "hevc"))
        )
    }

    /// `yuv410p` carries "10" in its name without being 10-bit. Reading the depth rather than the
    /// spelling is what keeps the two apart.
    @Test
    func aFormatWhoseNameContainsTenIsNotTakenForTenBit() {
        #expect(PixelGeometry.named("yuv410p") == PixelGeometry(chroma: .yuv410, depth: 8))

        let plan = RemuxPlanner.plan(for: [video(0, "mpeg4", pixelFormat: "yuv410p")])
        #expect(plan.recipe?.videoIndex == 0)
    }

    /// No pixel format, or one that isn't recognised, is refused rather than guessed at. The
    /// profile is not consulted: HEVC 4:2:2 reports itself as "Rext", which names no chroma at all.
    @Test
    func anUnreadablePixelFormatIsRefused() {
        #expect(
            RemuxPlanner.plan(for: [video(0, "hevc", pixelFormat: nil, profile: "Main 10")])
                == .unsupported(.video(codec: "hevc"))
        )
        #expect(
            RemuxPlanner.plan(for: [video(0, "hevc", pixelFormat: "yuv422p10le", profile: "Rext")])
                == .unsupported(.video(codec: "hevc"))
        )
        #expect(
            RemuxPlanner.plan(for: [video(0, "h264", pixelFormat: "not-a-format")])
                == .unsupported(.video(codec: "h264"))
        )
    }

    /// Both were listed as copyable and refused every time by the chroma rule, which hid the real
    /// reason: ffmpeg's MP4 muxer won't write ProRes at all, and the MJPEG it writes under the
    /// `mp4v` tag reports itself playable and then decodes nothing.
    @Test
    func proResAndMJPEGAreRefusedOnTheCodec() {
        #expect(
            RemuxPlanner.plan(for: [video(0, "prores", pixelFormat: "yuv422p10le")])
                == .unsupported(.video(codec: "prores"))
        )
        #expect(
            RemuxPlanner.plan(for: [video(0, "mjpeg", pixelFormat: "yuvj420p")])
                == .unsupported(.video(codec: "mjpeg"))
        )
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

    /// Both are common in Matroska and decode from an MP4 intact, so re-encoding them to AAC threw
    /// audio away for nothing.
    @Test(arguments: ["flac", "opus"])
    func losslessAndModernAudioIsCopiedRatherThanReEncoded(codec: String) {
        let plan = RemuxPlanner.plan(for: [video(0, "h264"), audio(1, codec)])

        #expect(plan.recipe?.transcodesAudio == false)
        if case .remux = plan {} else { Issue.record("Expected a straight remux, got \(plan)") }
    }

    /// PCM decodes as well, but copying it keeps a stream far larger than the AAC it would become.
    @Test
    func pcmIsStillReEncoded() {
        let plan = RemuxPlanner.plan(for: [video(0, "h264"), audio(1, "pcm_s16le")])

        #expect(plan.recipe?.transcodesAudio == true)
    }

    /// The app already plays MPEG-2 inside a transport stream, so refusing it in Matroska was the
    /// odd one out. 4:2:2 is a real MPEG-2 profile and stays refused.
    @Test
    func mpeg2VideoIsCopiedAtFourTwoZero() {
        let copied = RemuxPlanner.plan(for: [
            video(0, "mpeg2video", pixelFormat: "yuv420p"), audio(1, "ac3"),
        ])
        #expect(copied.recipe?.videoIndex == 0)
        // ffmpeg picks `mp4v` for it, which is the tag the conversion was verified against.
        #expect(copied.recipe?.videoTag == nil)

        let refused = RemuxPlanner.plan(for: [video(0, "mpeg2video", pixelFormat: "yuv422p")])
        #expect(refused == .unsupported(.video(codec: "mpeg2video")))
    }
}
