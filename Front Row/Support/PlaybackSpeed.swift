//
//  PlaybackSpeed.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import Foundation

/// Decides what playback rate a requested speed becomes, independent of `AVPlayer` so it can be
/// tested directly.
enum PlaybackSpeed {

    /// The rates playback can be set to. Past either end `AVPlayer` stops producing anything
    /// worth watching.
    static let range: ClosedRange<Float> = 0.05...2.0

    /// Whether `speed` is normal speed. Worth asking because the controls bar only shows a speed
    /// indicator when it isn't.
    static func isDefault(_ speed: Float) -> Bool {
        abs(speed - 1.0) < .ulpOfOne
    }

    /// Brings `speed` into range, snapping anything within rounding distance of normal speed
    /// exactly onto it - otherwise stepping up and back down by 5% would drift off 1.0 and leave
    /// the indicator showing at what is meant to be normal speed.
    static func clamped(_ speed: Float) -> Float {
        guard !isDefault(speed) else { return 1.0 }
        return min(max(speed, range.lowerBound), range.upperBound)
    }
}
