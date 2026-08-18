//
//  LineBufferTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

/// Collecting pipe output, which arrives in whatever sized pieces the kernel hands over.
struct LineBufferTests {

    @Test
    func wholeLinesComeOutAndAPartialOneWaits() {
        let buffer = LineBuffer()

        #expect(
            buffer.lines(from: Data("out_time_us=1\nout_time_us=2\nout_ti".utf8)) == [
                "out_time_us=1", "out_time_us=2",
            ])
        #expect(buffer.lines(from: Data("me_us=3\n".utf8)) == ["out_time_us=3"])
    }

    /// ffmpeg's progress blocks do not arrive on line boundaries. A key split across two reads has
    /// to be rejoined rather than reported as two unparseable halves.
    @Test
    func aLineSplitAcrossManyChunksIsRejoined() {
        let buffer = LineBuffer()

        for character in "progress=end" {
            #expect(buffer.lines(from: Data(String(character).utf8)).isEmpty)
        }
        #expect(buffer.lines(from: Data("\n".utf8)) == ["progress=end"])
    }

    @Test
    func nothingComesFromNothing() {
        let buffer = LineBuffer()
        #expect(buffer.lines(from: Data()).isEmpty)
    }

    @Test
    func trailingNewlinesDoNotInventEmptyLines() {
        let buffer = LineBuffer()
        #expect(buffer.lines(from: Data("a\n".utf8)) == ["a"])
        #expect(buffer.lines(from: Data("b\n".utf8)) == ["b"])
    }

    /// The reader handler runs on Foundation's queue while the conversion task is elsewhere, so
    /// the buffer is reached from more than one thread by design.
    @Test(.timeLimit(.minutes(1)))
    func concurrentReadsKeepEveryLine() async {
        let buffer = LineBuffer()
        let collected = Collected()

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<20 {
                group.addTask {
                    for line in buffer.lines(from: Data("chunk\(index)\n".utf8)) {
                        collected.append(line)
                    }
                }
            }
        }

        #expect(collected.value.count == 20)
    }
}

/// Gathers lines produced from several tasks at once.
private final class Collected: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []

    func append(_ line: String) {
        lock.withLock { lines.append(line) }
    }

    var value: [String] {
        lock.withLock { lines }
    }
}
