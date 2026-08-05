//
//  TimecodeTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

struct TimecodeTests {

    @Test
    func hoursMinutesAndSecondsAreRead() {
        #expect(Timecode.parse("1:02:03") == 3723)
    }

    @Test
    func aShortStringMeansTheSmallerUnits() {
        #expect(Timecode.parse("2:03") == 123)
        #expect(Timecode.parse("90") == 90)
    }

    @Test
    func unpaddedComponentsAreRead() {
        #expect(Timecode.parse("1:2:3") == 3723)
    }

    @Test
    func fractionalSecondsSurvive() {
        #expect(Timecode.parse("1:30.5") == 90.5)
    }

    /// Nothing readable at all is the only case that fails outright - anything with one usable
    /// component is worth seeking to.
    @Test
    func nothingReadableIsRejected() {
        #expect(Timecode.parse("") == nil)
        #expect(Timecode.parse("abc") == nil)
        #expect(Timecode.parse("::") == nil)
    }

    /// A component that isn't a number counts as zero, so a typo in one place doesn't throw away
    /// the parts the user did get right.
    @Test
    func anUnreadableComponentCountsAsZero() {
        #expect(Timecode.parse("1:2:x") == 3720)
    }

    /// Parsing doesn't range-check. A negative position is only rejected once the caller compares
    /// it against the file's duration.
    @Test
    func aNegativePositionIsParsedNotRejected() {
        #expect(Timecode.parse("-5") == -5)
    }
}
