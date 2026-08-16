//
//  FFmpegArguments.swift
//  Front Row
//
//  Created by Joshua Park on 8/15/26.
//

import Foundation

/// Builds the ffmpeg and ffprobe command lines.
///
/// Pure, so the arguments can be asserted in tests rather than discovered by watching a conversion
/// fail.
enum FFmpegArguments {

    /// AAC bitrate for a re-encoded track. Multichannel needs the headroom; stereo doesn't.
    static func audioBitrate(channels: Int?) -> String {
        (channels ?? 2) >= 6 ? "448k" : "256k"
    }

    /// Asks ffprobe for the stream details the planner needs, as JSON on stdout.
    static func probe(input: URL) -> [String] {
        [
            "-hide_banner",
            "-v", "error",
            "-of", "json",
            "-show_entries",
            "stream=index,codec_type,codec_name,profile,pix_fmt,channels"
                + ":stream_tags=language,title"
                + ":stream_disposition=default,forced,attached_pic",
            "-show_entries", "format=duration",
            "-i", input.path(percentEncoded: false),
        ]
    }

    /// Asks ffmpeg which encoders it was built with, so the AudioToolbox AAC encoder can be
    /// preferred where it exists.
    static let encoders = ["-hide_banner", "-loglevel", "error", "-encoders"]

    /// The conversion itself.
    ///
    /// Streams are mapped one at a time rather than with `-map 0`. Matroska files routinely carry
    /// font attachments and data streams that MP4 can't hold, and mapping the lot makes ffmpeg
    /// fail on files that would otherwise convert cleanly.
    static func remux(
        input: URL,
        output: URL,
        recipe: RemuxRecipe,
        aacEncoder: String
    ) -> [String] {
        var arguments = [
            "-nostdin",
            "-hide_banner",
            "-loglevel", "error",
            // Machine-readable progress on stdout, and none of the human-readable kind.
            "-progress", "pipe:1",
            "-nostats",
            "-i", input.path(percentEncoded: false),
        ]

        if let videoIndex = recipe.videoIndex {
            arguments += ["-map", "0:\(videoIndex)"]
        }
        for track in recipe.audio {
            arguments += ["-map", "0:\(track.index)"]
        }
        for index in recipe.subtitleIndices {
            arguments += ["-map", "0:\(index)"]
        }

        arguments += ["-c", "copy"]

        // Per-output-stream overrides, so a copyable AAC track sitting next to a DTS one isn't
        // re-encoded for its neighbour's sake. The indices here count output audio streams, which
        // follow the order they were mapped in above.
        for (outputIndex, track) in recipe.audio.enumerated() where track.transcodes {
            arguments += [
                "-c:a:\(outputIndex)", aacEncoder,
                "-b:a:\(outputIndex)", audioBitrate(channels: track.channels),
            ]
        }

        if !recipe.subtitleIndices.isEmpty {
            arguments += ["-c:s", "mov_text"]
        }
        if let videoTag = recipe.videoTag {
            arguments += ["-tag:v", videoTag]
        }

        arguments += [
            "-movflags", "+faststart",
            "-y",
            output.path(percentEncoded: false),
        ]

        return arguments
    }
}
