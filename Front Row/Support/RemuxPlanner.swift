//
//  RemuxPlanner.swift
//  Front Row
//
//  Created by Joshua Park on 8/15/26.
//

import CoreMedia
import Foundation
import VideoToolbox

/// An audio track and what has to happen to it.
struct PlannedAudio: Equatable, Sendable {
    var index: Int
    var codecName: String?
    var channels: Int?
    /// False when the track can be copied across untouched.
    var transcodes: Bool
}

/// A subtitle track that can't come along.
struct DroppedSubtitle: Equatable, Sendable {
    var codecName: String?
    var language: String?
}

/// Exactly which streams go into the MP4 and what happens to each on the way.
struct RemuxRecipe: Equatable, Sendable {
    /// Source index of the video track, absent for audio-only files.
    var videoIndex: Int?
    /// The `-tag:v` four-character code. MP4 defaults to `hev1`/`avc3`, which AVFoundation won't
    /// open, so the tag is what makes an otherwise valid remux playable.
    var videoTag: String?
    var audio: [PlannedAudio]
    /// Source indices of text subtitle tracks, all converted to `mov_text`.
    var subtitleIndices: [Int]
    var droppedSubtitles: [DroppedSubtitle]

    var transcodesAudio: Bool {
        audio.contains(where: \.transcodes)
    }

    /// The first track being converted, for the wording of the confirmation dialog.
    var firstTranscodedAudio: PlannedAudio? {
        audio.first(where: \.transcodes)
    }
}

/// Why a file is beyond help.
enum UnsupportedReason: Equatable, Sendable {
    /// The video codec can't be decoded, so a new container wouldn't change anything.
    case video(codec: String?)
    /// Nothing in the file is worth muxing.
    case noPlayableStreams
}

/// What to do with a Matroska file.
enum RemuxPlan: Equatable, Sendable {
    /// Every stream can be copied. Lossless, and about as fast as copying the file.
    case remux(RemuxRecipe)
    /// Video copies, but at least one audio track has to be re-encoded.
    case transcodingAudio(RemuxRecipe)
    case unsupported(UnsupportedReason)

    var recipe: RemuxRecipe? {
        switch self {
        case .remux(let recipe), .transcodingAudio(let recipe): recipe
        case .unsupported: nil
        }
    }
}

/// Decides whether a Matroska file's streams can be moved into an MP4 that AVFoundation will play.
///
/// Pure, and deliberately so: this table is the whole feature. Offering a conversion that produces
/// a file which opens to a black frame or plays silently is worse than refusing outright, so the
/// lists below are conservative - a codec is only copyable if AVFoundation is known to decode it
/// from an MP4.
enum RemuxPlanner {

    /// Video codecs AVFoundation decodes from an MP4.
    static let copyableVideoCodecs: Set<String> = [
        "h264", "hevc", "av1", "mpeg4", "prores", "mjpeg",
    ]

    /// Whether this Mac can decode AV1.
    ///
    /// VideoToolbox has no software AV1 decoder, so where the hardware can't do it - every Mac
    /// before the M3 - an AV1 MP4 simply won't open, however cleanly ffmpeg wrote it.
    static let canDecodeAV1: Bool = VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)

    /// Audio codecs AVFoundation decodes from an MP4. Everything else is re-encoded to AAC.
    static let copyableAudioCodecs: Set<String> = [
        "aac", "mp3", "alac", "ac3", "eac3",
    ]

    /// Subtitle codecs that carry text, and so can become `mov_text`.
    static let textSubtitleCodecs: Set<String> = [
        "subrip", "srt", "ass", "ssa", "mov_text", "text", "webvtt",
    ]

    /// Chroma subsampling and bit depths VideoToolbox can't decode, whatever the codec claims.
    ///
    /// Keyed on pixel format rather than profile because a file can report one and not the other,
    /// and because 10-bit 4:2:0 HEVC - the HDR case - has to stay on the supported side of the
    /// line while 10-bit H.264 does not.
    private static let unsupportedPixelFormatMarkers = ["422", "444", "p12", "p16"]

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

    private static func isCopyable(_ stream: ProbedStream, canDecodeAV1: Bool) -> Bool {
        guard let codecName = stream.codecName, copyableVideoCodecs.contains(codecName) else {
            return false
        }

        if codecName == "av1" && !canDecodeAV1 { return false }

        if let pixelFormat = stream.pixelFormat {
            let isUnsupportedFormat = unsupportedPixelFormatMarkers.contains {
                pixelFormat.contains($0)
            }
            if isUnsupportedFormat { return false }
            // VideoToolbox has no 10-bit H.264 decoder, though it handles 10-bit HEVC.
            if codecName == "h264" && pixelFormat.contains("10") { return false }
        } else if let profile = stream.profile {
            // No pixel format to go on, so read the same limits off the profile name.
            let isUnsupportedProfile =
                profile.contains("4:2:2") || profile.contains("4:4:4")
                || (codecName == "h264" && profile.contains("10"))
            if isUnsupportedProfile { return false }
        }

        return true
    }
}
