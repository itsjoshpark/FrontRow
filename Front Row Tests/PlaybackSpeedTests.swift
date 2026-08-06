//
//  PlaybackSpeedTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

struct PlaybackSpeedTests {

    @Test
    func aSpeedInRangePassesThrough() {
        #expect(PlaybackSpeed.clamped(1.5) == 1.5)
        #expect(PlaybackSpeed.clamped(0.5) == 0.5)
    }

    @Test
    func speedsBeyondTheRangeAreClamped() {
        #expect(PlaybackSpeed.clamped(5.0) == PlaybackSpeed.range.upperBound)
        #expect(PlaybackSpeed.clamped(0.0) == PlaybackSpeed.range.lowerBound)
        #expect(PlaybackSpeed.clamped(-1.0) == PlaybackSpeed.range.lowerBound)
    }

    @Test
    func theBoundsThemselvesAreKept() {
        #expect(PlaybackSpeed.clamped(PlaybackSpeed.range.lowerBound) == 0.05)
        #expect(PlaybackSpeed.clamped(PlaybackSpeed.range.upperBound) == 2.0)
    }

    /// Stepping up and back down by 5% has to land exactly on normal speed, or the controls bar
    /// keeps showing an indicator for a file that is playing normally.
    @Test
    func steppingBackToNormalSpeedLandsExactlyOnIt() {
        var speed: Float = 1.0
        for _ in 0..<3 { speed = PlaybackSpeed.clamped(speed + 0.05) }
        for _ in 0..<3 { speed = PlaybackSpeed.clamped(speed - 0.05) }

        #expect(speed == 1.0)
        #expect(PlaybackSpeed.isDefault(speed))
    }

    @Test
    func onlyNormalSpeedIsDefault() {
        #expect(PlaybackSpeed.isDefault(1.0))
        #expect(!PlaybackSpeed.isDefault(1.05))
        #expect(!PlaybackSpeed.isDefault(0.95))
    }
}
