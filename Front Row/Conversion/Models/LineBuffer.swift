//
//  LineBuffer.swift
//  Front Row
//
//  Created by Joshua Park on 8/15/26.
//

import Foundation

/// Splits pipe output into whole lines, holding back a trailing partial one until the rest of it
/// arrives in a later chunk.
final class LineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = ""

    func lines(from chunk: Data) -> [String] {
        lock.withLock {
            pending += String(decoding: chunk, as: UTF8.self)
            var lines = pending.components(separatedBy: "\n")
            pending = lines.removeLast()
            return lines
        }
    }
}
