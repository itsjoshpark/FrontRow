//
//  ResumePolicy.swift
//  Front Row
//
//  Created by Joshua Park on 7/19/26.
//

import Foundation

/// Decides whether a saved playback position is worth resuming from, and when playback is close
/// enough to the end to count as finished.
///
/// Both use the same end buffer, so a position too close to the end to be resumed from is also
/// never saved in the first place.
enum ResumePolicy {

    /// A saved position is only resumed if it's past this many seconds in.
    static let minimumPosition: TimeInterval = 3

    /// A position within this many seconds of the end counts as finished.
    static let endBuffer: TimeInterval = 5

    /// The position to seek to on open, or `nil` if the file should start from the beginning.
    static func resumeTarget(saved: TimeInterval?, duration: TimeInterval) -> TimeInterval? {
        guard let saved,
            duration.isFinite,
            saved > minimumPosition,
            saved < duration - endBuffer
        else { return nil }

        return saved
    }

    static func isAtEnd(currentTime: TimeInterval, duration: TimeInterval) -> Bool {
        guard duration > 0 else { return false }
        return currentTime >= duration - endBuffer
    }
}
