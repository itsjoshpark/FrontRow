//
//  ProcessBuffers.swift
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

/// Holds the running process so a cancellation arriving on another task can stop it.
final class ProcessBox: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var isCancelled = false

    /// Starts `process` and keeps hold of it, or returns false if cancellation got there first -
    /// in which case nothing is launched.
    ///
    /// Launching under the same lock, and only recording the process once it is actually running,
    /// is what keeps `cancel()` from terminating a process that hasn't started. That raises an
    /// Objective-C exception Swift cannot catch, so it would take the app down.
    func launch(_ process: Process) throws -> Bool {
        try lock.withLock {
            guard !isCancelled else { return false }
            try process.run()
            self.process = process
            return true
        }
    }

    func cancel() {
        let process = lock.withLock { () -> Process? in
            isCancelled = true
            return self.process
        }
        process?.terminate()
    }

    var wasCancelled: Bool {
        lock.withLock { isCancelled }
    }
}
