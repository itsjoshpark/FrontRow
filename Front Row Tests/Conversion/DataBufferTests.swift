//
//  DataBufferTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

/// Collecting pipe output that is kept whole, which arrives in whatever sized pieces the
/// kernel hands over.
struct DataBufferTests {

    @Test
    func appendedDataAccumulatesInOrder() {
        let buffer = DataBuffer()
        buffer.append(Data("ffmpeg".utf8))
        buffer.append(Data(" said no".utf8))

        #expect(String(decoding: buffer.value, as: UTF8.self) == "ffmpeg said no")
    }

    @Test
    func anUntouchedBufferIsEmpty() {
        #expect(DataBuffer().value.isEmpty)
    }

    /// A failing ffmpeg writes a lot, fast, from the reader queue. Nothing may be dropped: the
    /// message is what the failure alert shows.
    @Test(.timeLimit(.minutes(1)))
    func concurrentAppendsLoseNothing() async {
        let buffer = DataBuffer()
        let chunk = Data(repeating: UInt8(ascii: "x"), count: 1_000)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask { buffer.append(chunk) }
            }
        }

        #expect(buffer.value.count == 100_000)
    }
}
