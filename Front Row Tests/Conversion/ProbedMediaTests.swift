//
//  ProbedMediaTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

struct ProbedMediaTests {

    /// Captured from `ffprobe` against a Matroska file holding H.264, AAC and SubRip. Kept
    /// verbatim, empty `tags` objects and all, so the decoding is tested against what ffprobe
    /// really writes rather than a tidied-up version of it.
    private let realOutput = """
        {
            "programs": [],
            "stream_groups": [],
            "streams": [
                {
                    "index": 0,
                    "codec_name": "h264",
                    "profile": "High",
                    "codec_type": "video",
                    "pix_fmt": "yuv420p",
                    "disposition": { "default": 1, "forced": 0, "attached_pic": 0 },
                    "tags": {}
                },
                {
                    "index": 1,
                    "codec_name": "aac",
                    "profile": "LC",
                    "codec_type": "audio",
                    "channels": 6,
                    "disposition": { "default": 1, "forced": 0, "attached_pic": 0 },
                    "tags": { "language": "eng" }
                },
                {
                    "index": 2,
                    "codec_name": "subrip",
                    "codec_type": "subtitle",
                    "disposition": { "default": 0, "forced": 0, "attached_pic": 0 },
                    "tags": {}
                }
            ],
            "format": { "duration": "3.023000" }
        }
        """

    private func decode(_ json: String) throws -> ProbedMedia {
        try JSONDecoder().decode(ProbedMedia.self, from: Data(json.utf8))
    }

    @Test
    func ffprobeOutputDecodesIntoStreams() throws {
        let media = try decode(realOutput)

        #expect(media.streams.count == 3)
        #expect(media.streams[0].kind == .video)
        #expect(media.streams[0].pixelFormat == "yuv420p")
        #expect(media.streams[1].channels == 6)
        #expect(media.streams[1].tags?.language == "eng")
        #expect(media.streams[2].kind == .subtitle)
        // ffprobe writes the duration as a string, so it has to be converted rather than read.
        #expect(media.duration == 3.023)
    }

    /// ffprobe leaves out anything it has nothing to say about, and keys this app doesn't ask for
    /// still turn up. Neither may fail the decode.
    @Test
    func missingAndUnexpectedKeysAreTolerated() throws {
        let media = try decode(
            """
            {
                "streams": [
                    { "index": 0, "codec_type": "video", "codec_name": "hevc", "bit_rate": "800" }
                ]
            }
            """
        )

        #expect(media.streams.count == 1)
        #expect(media.streams[0].profile == nil)
        #expect(media.streams[0].tags == nil)
        #expect(media.duration == nil)
    }

    /// A duration of zero can't be divided by, so it has to read as unknown rather than as a
    /// number - otherwise progress reporting divides by it.
    @Test
    func anUnusableDurationReadsAsUnknown() throws {
        #expect(try decode(#"{"streams": [], "format": {"duration": "0.000000"}}"#).duration == nil)
        #expect(try decode(#"{"streams": [], "format": {"duration": "N/A"}}"#).duration == nil)
    }

    /// A stream ffprobe reports as attached cover art has to be recognisable as such.
    @Test
    func coverArtIsFlagged() throws {
        let media = try decode(
            """
            {
                "streams": [
                    {
                        "index": 0, "codec_type": "video", "codec_name": "mjpeg",
                        "disposition": { "attached_pic": 1 }
                    }
                ]
            }
            """
        )

        #expect(media.streams[0].isAttachedPicture)
    }
}
