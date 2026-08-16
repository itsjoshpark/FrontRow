//
//  FFmpegProgressParser.swift
//  Front Row
//
//  Created by Joshua Park on 8/15/26.
//

import Foundation

/// Something worth reporting from ffmpeg's progress stream.
enum FFmpegProgressEvent: Equatable, Sendable {
    /// How far through the file ffmpeg has written, from 0 to 1.
    case fraction(Double)
    case finished
}

/// Reads the `key=value` lines `-progress pipe:1` writes to stdout.
///
/// ffmpeg emits a block of these every half-second or so; everything but the position and the
/// final marker is noise here.
struct FFmpegProgressParser: Sendable {

    /// The source duration in seconds, or `nil` when ffprobe couldn't measure one - in which case
    /// no fraction can be worked out and progress stays indeterminate.
    let duration: TimeInterval?

    func event(for line: String) -> FFmpegProgressEvent? {
        let fields = line.split(separator: "=", maxSplits: 1)
        guard fields.count == 2 else { return nil }

        let key = fields[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let value = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)

        switch key {
        case "progress":
            return value == "end" ? .finished : nil
        case "out_time_us":
            guard let duration, duration > 0, let microseconds = Double(value) else { return nil }
            return .fraction(min(max(microseconds / 1_000_000 / duration, 0), 1))
        default:
            return nil
        }
    }
}
