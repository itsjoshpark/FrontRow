//
//  FFmpegArgumentsTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

struct FFmpegArgumentsTests {

    private let input = URL(fileURLWithPath: "/Movies/film.mkv")
    private let output = URL(fileURLWithPath: "/Movies/film.mp4")

    private func arguments(_ recipe: RemuxRecipe, aacEncoder: String = "aac_at") -> [String] {
        FFmpegArguments.remux(
            input: input, output: output, recipe: recipe, aacEncoder: aacEncoder)
    }

    /// A straight copy with the tag AVFoundation needs, and no encoder options at all.
    @Test
    func aLosslessRemuxCopiesEveryStream() {
        let arguments = arguments(
            RemuxRecipe(
                videoIndex: 0,
                videoTag: "avc1",
                audio: [PlannedAudio(index: 1, codecName: "aac", channels: 2, transcodes: false)],
                subtitleIndices: [],
                droppedSubtitles: []
            )
        )

        #expect(arguments.contains(["-c", "copy"]))
        #expect(arguments.contains(["-tag:v", "avc1"]))
        #expect(!arguments.contains("-c:a:0"))
        #expect(!arguments.contains("-c:s"))
    }

    /// Streams are named one at a time rather than with `-map 0`, which would also drag in the
    /// font attachments Matroska files carry and that MP4 can't hold.
    @Test
    func onlyTheChosenStreamsAreMappedAndDroppedOnesAreAbsent() {
        let arguments = arguments(
            RemuxRecipe(
                videoIndex: 0,
                videoTag: "hvc1",
                audio: [PlannedAudio(index: 1, codecName: "aac", channels: 2, transcodes: false)],
                // Index 2 was a bitmap subtitle and 4 an attachment; neither may be mapped.
                subtitleIndices: [3],
                droppedSubtitles: [DroppedSubtitle(codecName: "hdmv_pgs_subtitle", language: "eng")]
            )
        )

        #expect(arguments.contains(["-map", "0:0"]))
        #expect(arguments.contains(["-map", "0:1"]))
        #expect(arguments.contains(["-map", "0:3"]))
        #expect(!arguments.contains(["-map", "0:2"]))
        #expect(!arguments.contains(["-map", "0:4"]))
        #expect(!arguments.contains(["-map", "0"]))
        #expect(arguments.contains(["-c:s", "mov_text"]))
    }

    /// The encoder options are pinned to the output audio stream that needs them, so the copyable
    /// track beside it is still copied.
    @Test
    func onlyTheTranscodedTrackGetsEncoderOptions() {
        let arguments = arguments(
            RemuxRecipe(
                videoIndex: 0,
                videoTag: "hvc1",
                audio: [
                    PlannedAudio(index: 1, codecName: "aac", channels: 2, transcodes: false),
                    PlannedAudio(index: 2, codecName: "dts", channels: 6, transcodes: true),
                ],
                subtitleIndices: [],
                droppedSubtitles: []
            )
        )

        #expect(!arguments.contains("-c:a:0"))
        #expect(arguments.contains(["-c:a:1", "aac_at"]))
        #expect(arguments.contains(["-b:a:1", "448k"]))
    }

    /// Stereo doesn't need the bitrate multichannel does, and 7.1 doesn't fit in 5.1's budget.
    @Test
    func theBitrateFollowsTheChannelCount() {
        #expect(FFmpegArguments.audioBitrate(channels: 1) == "256k")
        #expect(FFmpegArguments.audioBitrate(channels: 2) == "256k")
        #expect(FFmpegArguments.audioBitrate(channels: nil) == "256k")
        #expect(FFmpegArguments.audioBitrate(channels: 5) == "256k")
        #expect(FFmpegArguments.audioBitrate(channels: 6) == "448k")
        #expect(FFmpegArguments.audioBitrate(channels: 7) == "640k")
        #expect(FFmpegArguments.audioBitrate(channels: 8) == "640k")
    }

    /// The rate is pinned to the track that needs it, so a 7.1 track gets its own budget rather
    /// than the one its 5.1 neighbour asked for.
    @Test
    func aSevenPointOneTrackIsGivenItsOwnBitrate() {
        let arguments = arguments(
            RemuxRecipe(
                videoIndex: 0,
                videoTag: "hvc1",
                audio: [
                    PlannedAudio(index: 1, codecName: "dts", channels: 6, transcodes: true),
                    PlannedAudio(index: 2, codecName: "truehd", channels: 8, transcodes: true),
                ],
                subtitleIndices: [],
                droppedSubtitles: []
            )
        )

        #expect(arguments.contains(["-b:a:0", "448k"]))
        #expect(arguments.contains(["-b:a:1", "640k"]))
    }

    /// ffmpeg reports progress on stdout only when asked, and would otherwise wait on stdin it is
    /// never going to get.
    @Test
    func progressIsRequestedAndTheProcessNeverWaitsOnInput() {
        let arguments = arguments(
            RemuxRecipe(
                videoIndex: 0, videoTag: nil, audio: [], subtitleIndices: [], droppedSubtitles: [])
        )

        #expect(arguments.contains(["-progress", "pipe:1"]))
        #expect(arguments.contains("-nostats"))
        #expect(arguments.contains("-nostdin"))
        #expect(arguments.last == "/Movies/film.mp4")
    }

    /// The output name is checked for collisions before ffmpeg runs, so a file appearing at that
    /// path in the meantime belongs to someone else. Refuse it rather than overwrite it.
    @Test
    func anExistingOutputIsNeverOverwritten() {
        let arguments = arguments(
            RemuxRecipe(
                videoIndex: 0, videoTag: nil, audio: [], subtitleIndices: [], droppedSubtitles: [])
        )

        #expect(arguments.contains("-n"))
        #expect(!arguments.contains("-y"))
    }

    /// ffmpeg writes to the working file while it works, and picks its muxer from the extension
    /// unless told otherwise - so without this it would refuse the conversion outright.
    @Test
    func theOutputFormatIsNamedRatherThanGuessedFromTheExtension() {
        let arguments = arguments(
            RemuxRecipe(
                videoIndex: 0, videoTag: nil, audio: [], subtitleIndices: [], droppedSubtitles: [])
        )

        #expect(arguments.contains(["-f", "mp4"]))
        #expect(arguments.last == "/Movies/film.mp4")
    }

    /// ffprobe has to be asked for JSON, for the fields the planner reads, and for the duration
    /// the progress percentage is worked out from.
    @Test
    func theProbeAsksForParsableOutput() {
        let arguments = FFmpegArguments.probe(input: input)

        #expect(arguments.contains(["-of", "json"]))
        #expect(arguments.contains(["-show_entries", "format=duration"]))
        #expect(arguments.contains { $0.contains("attached_pic") })
        #expect(arguments.contains { $0.contains("pix_fmt") })
        #expect(arguments.last == "/Movies/film.mkv")
    }
}

extension Array where Element: Equatable {
    /// Whether these elements appear in order and next to each other, so an option and its value
    /// can be asserted as the pair they are.
    fileprivate func contains(_ subsequence: [Element]) -> Bool {
        guard !subsequence.isEmpty, count >= subsequence.count else { return false }
        return indices.dropLast(subsequence.count - 1).contains { start in
            Array(self[start..<(start + subsequence.count)]) == subsequence
        }
    }
}
