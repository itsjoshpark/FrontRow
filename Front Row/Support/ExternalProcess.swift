//
//  ExternalProcess.swift
//  Front Row
//
//  Created by Joshua Park on 8/15/26.
//

import Foundation

/// Runs a command-line tool and collects what it printed.
///
/// For short-lived commands whose output is read once it has finished. A conversion reports as it
/// goes and is run by `MediaRemuxer` instead.
enum ExternalProcess {

    struct Output: Sendable {
        var standardOutput: Data
        var standardError: String
        var terminationStatus: Int32

        var didSucceed: Bool { terminationStatus == 0 }
    }

    static func run(_ executable: URL, arguments: [String]) async throws -> Output {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            process.standardInput = FileHandle.nullDevice

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // Drained as it arrives: a chatty failure could otherwise fill the error pipe and stall
            // the child while this side is still blocked reading stdout.
            let errorBuffer = DataBuffer()
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                errorBuffer.append(handle.availableData)
            }

            try process.run()

            let standardOutput = outputPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            errorPipe.fileHandleForReading.readabilityHandler = nil
            errorBuffer.append(errorPipe.fileHandleForReading.availableData)

            return Output(
                standardOutput: standardOutput,
                standardError: String(decoding: errorBuffer.value, as: UTF8.self),
                terminationStatus: process.terminationStatus
            )
        }.value
    }
}

/// Collects pipe output arriving on Foundation's reader queue.
final class DataBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        lock.withLock { data.append(newData) }
    }

    var value: Data {
        lock.withLock { data }
    }
}

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

    /// Returns false if cancellation already arrived, in which case the process must not start.
    func adopt(_ process: Process) -> Bool {
        lock.withLock {
            guard !isCancelled else { return false }
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
