//
//  RemuxPlanner.swift
//  Front Row
//
//  Created by Joshua Park on 8/15/26.
//

import CoreMedia
import Foundation
import VideoToolbox

/// Decides whether a Matroska file's streams can be moved into an MP4 that AVFoundation will play.
///
/// Pure, and deliberately so: this table is the whole feature. Offering a conversion that produces
/// a file which opens to a black frame or plays silently is worse than refusing outright, so the
/// lists below are conservative - a codec is only copyable if AVFoundation is known to decode it
/// from an MP4.
enum RemuxPlanner {

    /// Video codecs AVFoundation decodes from an MP4.
    ///
    /// ProRes and MJPEG are deliberately absent. ffmpeg's MP4 muxer refuses ProRes outright, and
    /// writes MJPEG under the `mp4v` tag - which AVFoundation reports as playable and then cannot
    /// decode. Neither can be made to work without leaving the MP4 container.
    private static let copyableVideoCodecs: Set<String> = [
        "h264", "hevc", "av1", "mpeg4",
    ]

    /// Whether this Mac can decode AV1.
    ///
    /// VideoToolbox has no software AV1 decoder, so where the hardware can't do it - every Mac
    /// before the M3 - an AV1 MP4 simply won't open, however cleanly ffmpeg wrote it.
    static let canDecodeAV1: Bool = VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)

    /// Audio codecs AVFoundation decodes from an MP4. Everything else is re-encoded to AAC.
    private static let copyableAudioCodecs: Set<String> = [
        "aac", "mp3", "alac", "ac3", "eac3",
    ]

    /// Subtitle codecs that carry text, and so can become `mov_text`.
    private static let textSubtitleCodecs: Set<String> = [
        "subrip", "srt", "ass", "ssa", "mov_text", "text", "webvtt",
    ]

    /// The chroma and depth each codec's decoder will take.
    ///
    /// Stated per codec because the limits differ: 10-bit 4:2:0 HEVC - the HDR case - has to stay
    /// on the supported side of the line while 10-bit H.264 does not.
    private static func decodes(_ geometry: PixelGeometry, as codecName: String) -> Bool {
        switch codecName {
        case "h264":
            isLowChroma(geometry.chroma) && geometry.depth <= 8
        case "hevc", "av1":
            isLowChroma(geometry.chroma) && geometry.depth <= 10
        case "mpeg4":
            isLowChroma(geometry.chroma) && geometry.depth <= 8
        default:
            false
        }
    }

    /// 4:2:0 and below, which is everything these decoders handle.
    private static func isLowChroma(_ chroma: PixelGeometry.Chroma) -> Bool {
        switch chroma {
        case .monochrome, .yuv410, .yuv411, .yuv420: true
        case .yuv422, .yuv444, .rgb: false
        }
    }

    static func plan(
        for streams: [ProbedStream],
        canDecodeAV1: Bool = canDecodeAV1
    ) -> RemuxPlan {
        // Cover art reports itself as video. Muxing it as the video track would produce a file
        // that shows one still frame for its whole duration.
        let videoStreams = streams.filter { $0.kind == .video && !$0.isAttachedPicture }
        let audioStreams = streams.filter { $0.kind == .audio }
        let subtitleStreams = streams.filter { $0.kind == .subtitle }

        guard !videoStreams.isEmpty || !audioStreams.isEmpty else {
            return .unsupported(.noPlayableStreams)
        }

        // Extra video tracks are dropped rather than refused: they're almost always thumbnails or
        // alternate angles, and the first track is what the user came to watch.
        let video = videoStreams.first
        if let video, !isCopyable(video, canDecodeAV1: canDecodeAV1) {
            return .unsupported(.video(codec: video.codecName))
        }

        let audio = audioStreams.map { stream in
            PlannedAudio(
                index: stream.index,
                codecName: stream.codecName,
                channels: stream.channels,
                transcodes: !copyableAudioCodecs.contains(stream.codecName ?? "")
            )
        }

        let textSubtitles = subtitleStreams.filter {
            textSubtitleCodecs.contains($0.codecName ?? "")
        }
        let bitmapSubtitles = subtitleStreams.filter {
            !textSubtitleCodecs.contains($0.codecName ?? "")
        }

        let recipe = RemuxRecipe(
            videoIndex: video?.index,
            videoTag: video.flatMap { videoTag(for: $0.codecName) },
            audio: audio,
            subtitleIndices: textSubtitles.map(\.index),
            droppedSubtitles: bitmapSubtitles.map {
                DroppedSubtitle(codecName: $0.codecName, language: $0.tags?.language)
            }
        )

        return recipe.transcodesAudio ? .transcodingAudio(recipe) : .remux(recipe)
    }

    /// The `-tag:v` code a codec needs, or `nil` where the container default is already right.
    static func videoTag(for codecName: String?) -> String? {
        switch codecName {
        case "hevc": "hvc1"
        case "h264": "avc1"
        case "av1": "av01"
        default: nil
        }
    }

    /// A stream with no pixel format, or one this doesn't recognise, is refused rather than
    /// guessed at. The profile name is not read as a fallback: HEVC 4:2:2 reports itself as
    /// `Rext`, so the profile misses the very case it would be consulted for.
    private static func isCopyable(_ stream: ProbedStream, canDecodeAV1: Bool) -> Bool {
        guard let codecName = stream.codecName, copyableVideoCodecs.contains(codecName) else {
            return false
        }

        if codecName == "av1" && !canDecodeAV1 { return false }

        guard
            let pixelFormat = stream.pixelFormat,
            let geometry = PixelGeometry.named(pixelFormat)
        else { return false }

        return decodes(geometry, as: codecName)
    }
}
