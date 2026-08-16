//
//  FileOpenResult.swift
//  Front Row
//
//  Created by Joshua Park on 7/17/26.
//

import Foundation

/// The outcome of trying to open a media file.
///
/// AVFoundation distinguishes "couldn't read this" from "read it, can't decode it", and the two
/// call for different UI: the first may mean the file is gone or its drive is unplugged, the
/// second means it's sitting right there in an unsupported format.
enum FileOpenResult {
    case opened
    /// The file couldn't be read at all - deleted, or on a disconnected volume.
    case unreadable
    /// The file was read, but it isn't a format that can be played.
    case unplayable
    /// The file is in a container AVFoundation can't open, and `MediaConversion` has taken it from
    /// here. It raises its own alerts, so callers should say nothing further.
    case handedToConverter
}
