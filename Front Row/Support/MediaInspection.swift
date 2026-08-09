//
//  MediaInspection.swift
//  Front Row
//
//  Created by Joshua Park on 8/8/26.
//

import CoreMedia
import Foundation

/// Everything the Inspector knows about the loaded file.
///
/// A snapshot, not a live view: it describes the asset rather than playback, so it only changes
/// when a different file is opened. Any field AVFoundation doesn't report is `nil` and shows as
/// "N/A".
struct MediaInspection: Equatable {
    var video: VideoSummary?
    var colour: ColourSummary?
    var audio: AudioSummary?
    var tracks: [TrackSummary] = []
    var file: FileSummary
}

struct VideoSummary: Equatable {
    var formatCode: String
    var codecName: String
    var encoder: String?
    var isHardwareDecodeSupported: Bool
    var dimensions: CGSize?
    var rotationDegrees: Int
    var bitRate: Double?
    var frameRate: Double?
}

/// The colour pipeline the video was encoded against.
struct ColourSummary: Equatable {
    var primaries: String?
    var transferFunction: String?
    var matrix: String?
    var isFullRange: Bool?
    var bitDepth: Int?
    var isHDR: Bool
}

struct AudioSummary: Equatable {
    var formatCode: String
    var codecName: String
    var channels: String
    var bitRate: Double?
    var sampleRate: Double?
    var bitDepth: Int?
}

enum TrackKind: Equatable {
    case video
    case audio
    case subtitle
    case closedCaption
    case other(String)
}

struct TrackSummary: Equatable, Identifiable {
    var id: CMPersistentTrackID
    var kind: TrackKind
    var formatCode: String?
    var codecName: String?
    var isEnabled: Bool
    var isSelected: Bool
    var isMainProgram: Bool
    var isForced: Bool
    var title: String?
    var languageName: String?
    var dataSize: Int64?
    var dimensions: CGSize?
    var frameRate: Double?
    var channels: String?
    var sampleRate: Double?
    var bitRate: Double?
}

struct ChapterSummary: Equatable, Identifiable {
    var id: Int
    var title: String?
    var start: TimeInterval
}

/// A metadata field carried inside the file, such as its title or artist.
struct MetadataEntry: Equatable, Identifiable {
    var id: String
    var label: String
    var value: String
}

struct FileSummary: Equatable {
    var url: URL
    var isLocal: Bool
    var byteSize: Int64?
    var containerName: String?
    var duration: TimeInterval?
    var createdAt: Date?
    var modifiedAt: Date?
    var chapters: [ChapterSummary] = []
    var metadata: [MetadataEntry] = []
}
