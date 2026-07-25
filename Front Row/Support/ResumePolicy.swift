//
//  ResumePolicy.swift
//  Front Row
//
//  Created by Joshua Park on 7/24/26.
//

import Foundation

/// Decides whether a saved playback position is worth resuming from, independent of `AVPlayer` so
/// it can be tested directly.
enum ResumePolicy {

    /// A saved position must be past this to be worth resuming (skips negligible progress).
    static let minimumPosition: TimeInterval = 3

    /// A saved position must be at least this far from the end to be worth resuming, and playback
    /// within this distance of the end is considered finished.
    static let endBuffer: TimeInterval = 5

    /// Returns `saved` if it's far enough in and not effectively finished, otherwise `nil`.
    ///
    /// Requires a bounded duration: an unknown (`nan`) or indeterminate (`infinity`, as reported
    /// for live streams) one gives no end to measure "effectively finished" against.
    static func resumePosition(saved: TimeInterval?, duration: TimeInterval) -> TimeInterval? {
        guard let saved, duration.isFinite, saved > minimumPosition, saved < duration - endBuffer
        else { return nil }
        return saved
    }

    /// Whether `currentTime` is close enough to `duration` to count as finished.
    static func isAtEnd(currentTime: TimeInterval, duration: TimeInterval) -> Bool {
        guard duration > 0 else { return false }
        return currentTime >= duration - endBuffer
    }
}
