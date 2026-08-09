//
//  MediaValueFormat.swift
//  Front Row
//
//  Created by Joshua Park on 8/8/26.
//

import Foundation

/// Renders the numbers the Inspector shows at the precision each one is worth reading at.
enum MediaValueFormat {

    /// A data rate in the largest unit that leaves it readable, so a 6 Mbps video doesn't read as
    /// `5997797 bps`.
    static func bitRate(_ bitsPerSecond: Double) -> String {
        let value = bitsPerSecond.rounded()
        // The kbps branch rounds to whole kilobits, so anything that would reach four digits
        // there belongs in the larger unit instead.
        if value >= 999_500 {
            let megabits = (value / 1_000_000).formatted(.number.precision(.fractionLength(0...1)))
            return String(localized: "\(megabits) Mbps", comment: "Megabits per second")
        }
        if value >= 1000 {
            let kilobits = (value / 1000).formatted(.number.precision(.fractionLength(0)))
            return String(localized: "\(kilobits) kbps", comment: "Kilobits per second")
        }
        return String(
            localized: "\(value.formatted(.number.precision(.fractionLength(0)))) bps",
            comment: "Bits per second"
        )
    }

    static func sampleRate(_ hertz: Double) -> String {
        let kilohertz = (hertz / 1000).formatted(.number.precision(.fractionLength(0...1)))
        return String(localized: "\(kilohertz) kHz", comment: "Audio sample rate in kilohertz")
    }

    /// Frame rates are the one place trailing decimals matter - 23.976 and 24 are different files.
    static func frameRate(_ framesPerSecond: Double) -> String {
        let value = framesPerSecond.formatted(.number.precision(.fractionLength(0...3)))
        return String(localized: "\(value) fps", comment: "Frames per second")
    }

    static func dimensions(_ size: CGSize) -> String {
        let width = Int(size.width).formatted(.number.grouping(.never))
        let height = Int(size.height).formatted(.number.grouping(.never))
        return "\(width) × \(height)"
    }

    static func byteSize(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file))
    }

    static func bitDepth(_ bits: Int) -> String {
        String(localized: "\(bits)-bit", comment: "Colour or audio bit depth, e.g. 10-bit")
    }

    static func duration(_ seconds: TimeInterval) -> String {
        seconds.asTimecode(using: seconds)
    }

    /// A position within a file, padded to the length of the whole file rather than to its own
    /// magnitude, so a column of them lines up instead of gaining an hour partway down.
    static func position(_ seconds: TimeInterval, in duration: TimeInterval) -> String {
        seconds.asTimecode(using: duration)
    }

    static func rotation(_ degrees: Int) -> String {
        "\(degrees.formatted(.number))°"
    }

    static func kindName(_ kind: TrackKind) -> String {
        switch kind {
        case .video:
            String(
                localized: "Video",
                comment: "The file's video, as a section heading and a track type")
        case .audio:
            String(
                localized: "Audio",
                comment: "The file's audio, as a section heading and a track type")
        case .subtitle: String(localized: "Subtitle", comment: "A subtitle track")
        case .text: String(localized: "Text", comment: "A text track, such as a chapter track")
        case .closedCaption:
            String(localized: "Closed Captions", comment: "A closed caption track")
        case .other(let mediaType): mediaType
        }
    }

    /// A one-line description of a track for the Tracks tab's picker, naming whatever tells this
    /// track apart from its siblings - resolution and frame rate for video, layout for audio,
    /// language for subtitles.
    static func trackLabel(for track: TrackSummary) -> String {
        var details: [String] = []
        if let codec = track.formatCode { details.append(codec) }
        if let dimensions = track.dimensions { details.append(self.dimensions(dimensions)) }
        if let channels = track.channels { details.append(channels) }
        if let frameRate = track.frameRate { details.append(self.frameRate(frameRate)) }
        if let language = track.languageName { details.append(language) }
        if let title = track.title { details.append(title) }

        let name = "\(kindName(track.kind)) #\(track.id.formatted(.number.grouping(.never)))"
        return details.isEmpty ? name : "\(name) — \(details.joined(separator: ", "))"
    }
}
