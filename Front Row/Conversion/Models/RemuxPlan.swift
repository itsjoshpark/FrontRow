//
//  RemuxPlan.swift
//  Front Row
//
//  Created by Joshua Park on 8/15/26.
//

import Foundation

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
