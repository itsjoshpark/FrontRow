//
//  ResumePolicyTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

struct ResumePolicyTests {

    @Test
    func aMidFilePositionIsResumed() {
        #expect(ResumePolicy.resumePosition(saved: 120, duration: 600) == 120)
    }

    @Test
    func noSavedPositionIsNotResumed() {
        #expect(ResumePolicy.resumePosition(saved: nil, duration: 600) == nil)
    }

    @Test
    func aPositionNearTheStartIsNotResumed() {
        #expect(ResumePolicy.resumePosition(saved: 1, duration: 600) == nil)
    }

    @Test
    func aPositionNearTheEndIsNotResumed() {
        #expect(ResumePolicy.resumePosition(saved: 598, duration: 600) == nil)
    }

    /// An indeterminate duration (`AVPlayer` reports `.infinity` for live streams) gives no end to
    /// measure against, so there's no way to tell a resumable position from a finished one.
    @Test
    func aPositionIsNotResumedWhenDurationIsUnbounded() {
        #expect(ResumePolicy.resumePosition(saved: 120, duration: .infinity) == nil)
    }

    @Test
    func aPositionIsNotResumedWhenDurationIsUnknown() {
        #expect(ResumePolicy.resumePosition(saved: 120, duration: .nan) == nil)
    }

    @Test
    func isAtEndIsTrueWithinTheEndBuffer() {
        #expect(ResumePolicy.isAtEnd(currentTime: 597, duration: 600))
    }

    @Test
    func isAtEndIsFalseWellBeforeTheEnd() {
        #expect(!ResumePolicy.isAtEnd(currentTime: 300, duration: 600))
    }

    @Test
    func isAtEndIsFalseWhenDurationIsUnknown() {
        #expect(!ResumePolicy.isAtEnd(currentTime: 300, duration: 0))
    }

    @Test
    func isAtEndIsFalseWhenDurationIsUnbounded() {
        #expect(!ResumePolicy.isAtEnd(currentTime: 300, duration: .infinity))
    }
}
