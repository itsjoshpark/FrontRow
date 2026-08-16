//
//  ProbedStream.swift
//  Front Row
//
//  Created by Joshua Park on 8/15/26.
//

import Foundation

/// One stream of a media file, as `ffprobe` describes it.
///
/// Everything past `index` is optional because ffprobe omits keys it has nothing to say about:
/// an audio stream has no pixel format, and plenty of files carry no tags at all.
struct ProbedStream: Decodable, Equatable, Sendable {

    enum Kind: String, Decodable, Sendable {
        case video
        case audio
        case subtitle
        case attachment
        case data
    }

    struct Tags: Decodable, Equatable, Sendable {
        var language: String?
        var title: String?
    }

    struct Disposition: Decodable, Equatable, Sendable {
        var `default`: Int?
        var forced: Int?
        /// Set on cover art, which ffprobe reports as a video stream even though there's no video
        /// in it.
        var attachedPic: Int?

        enum CodingKeys: String, CodingKey {
            case `default`
            case forced
            case attachedPic = "attached_pic"
        }
    }

    var index: Int
    var kind: Kind?
    var codecName: String?
    var profile: String?
    var pixelFormat: String?
    var channels: Int?
    var tags: Tags?
    var disposition: Disposition?

    enum CodingKeys: String, CodingKey {
        case index
        case kind = "codec_type"
        case codecName = "codec_name"
        case profile
        case pixelFormat = "pix_fmt"
        case channels
        case tags
        case disposition
    }

    /// Cover art masquerading as a video stream.
    var isAttachedPicture: Bool {
        disposition?.attachedPic == 1
    }
}

/// The whole of what `ffprobe` reports about a file.
struct ProbedMedia: Decodable, Equatable, Sendable {

    struct Format: Decodable, Equatable, Sendable {
        /// ffprobe writes this as a string, and leaves it out for files it can't measure.
        var duration: String?
    }

    var streams: [ProbedStream]
    var format: Format?

    /// The file's duration, or `nil` when ffprobe couldn't determine one. Progress reporting falls
    /// back to indeterminate without it.
    var duration: TimeInterval? {
        guard let duration = format?.duration, let seconds = TimeInterval(duration), seconds > 0
        else { return nil }
        return seconds
    }
}
