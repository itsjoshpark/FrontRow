//
//  ResumePolicyTests.swift
//  Front RowTests
//
//  Created by Joshua Park on 7/19/26.
//

import Foundation
import Testing

@testable import Front_Row

struct ResumePolicyTests {

    @Test func resumesFromMidFilePosition() {
        #expect(ResumePolicy.resumeTarget(saved: 500, duration: 1000) == 500)
    }

    @Test func ignoresPositionInTheOpeningSeconds() {
        #expect(
            ResumePolicy.resumeTarget(saved: ResumePolicy.minimumPosition, duration: 1000) == nil)
        #expect(ResumePolicy.resumeTarget(saved: 0, duration: 1000) == nil)
    }

    @Test func ignoresPositionWithinTheEndBuffer() {
        #expect(
            ResumePolicy.resumeTarget(saved: 1000 - ResumePolicy.endBuffer, duration: 1000) == nil)
        #expect(ResumePolicy.resumeTarget(saved: 1000, duration: 1000) == nil)
    }

    @Test func ignoresUnusableDuration() {
        #expect(ResumePolicy.resumeTarget(saved: 500, duration: .nan) == nil)
        #expect(ResumePolicy.resumeTarget(saved: 500, duration: .infinity) == nil)
    }

    @Test func ignoresMissingPosition() {
        #expect(ResumePolicy.resumeTarget(saved: nil, duration: 1000) == nil)
    }

    /// A position too close to the end to resume from must also count as finished, so it's never
    /// saved in the first place.
    @Test func endBufferAgreesWithResumeTarget() {
        let saved = 1000 - ResumePolicy.endBuffer
        #expect(ResumePolicy.resumeTarget(saved: saved, duration: 1000) == nil)
        #expect(ResumePolicy.isAtEnd(currentTime: saved, duration: 1000))
    }

    @Test func midFilePlaybackIsNotAtEnd() {
        #expect(!ResumePolicy.isAtEnd(currentTime: 500, duration: 1000))
    }

    /// Duration is reset to zero while a file is being swapped in; nothing should read as finished.
    @Test func unknownDurationIsNotAtEnd() {
        #expect(!ResumePolicy.isAtEnd(currentTime: 500, duration: 0))
    }
}
