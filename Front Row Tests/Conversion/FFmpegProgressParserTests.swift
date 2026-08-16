//
//  FFmpegProgressParserTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

struct FFmpegProgressParserTests {

    private let parser = FFmpegProgressParser(duration: 100)

    /// ffmpeg reports the position in microseconds, which has to become a fraction of the whole.
    @Test
    func thePositionBecomesAFractionOfTheDuration() {
        #expect(parser.event(for: "out_time_us=25000000") == .fraction(0.25))
        #expect(parser.event(for: "out_time_us=0") == .fraction(0))
    }

    /// ffmpeg's last position can overshoot the duration ffprobe measured, and a bar that reads
    /// 104% looks broken.
    @Test
    func anOvershootIsClampedToTheEnd() {
        #expect(parser.event(for: "out_time_us=104000000") == .fraction(1))
    }

    @Test
    func theEndMarkerFinishes() {
        #expect(parser.event(for: "progress=end") == .finished)
        #expect(parser.event(for: "progress=continue") == nil)
    }

    /// Every block ffmpeg writes is mostly keys this doesn't care about, and a line can arrive
    /// split or malformed.
    @Test
    func everythingElseIsIgnored() {
        #expect(parser.event(for: "frame=241") == nil)
        #expect(parser.event(for: "bitrate=N/A") == nil)
        #expect(parser.event(for: "out_time_us=N/A") == nil)
        #expect(parser.event(for: "") == nil)
        #expect(parser.event(for: "out_time_us") == nil)
        #expect(parser.event(for: "=5") == nil)
    }

    /// A trailing carriage return must not stop the end marker being recognised.
    @Test
    func surroundingWhitespaceIsTrimmed() {
        #expect(parser.event(for: "progress=end\r") == .finished)
        #expect(parser.event(for: " out_time_us = 50000000 ") == .fraction(0.5))
    }

    /// Nothing can be worked out for a file whose length ffprobe couldn't measure, so progress
    /// stays indeterminate rather than dividing by zero.
    @Test
    func withoutADurationThereIsNoFraction() {
        let parser = FFmpegProgressParser(duration: nil)

        #expect(parser.event(for: "out_time_us=25000000") == nil)
        #expect(parser.event(for: "progress=end") == .finished)
    }
}
