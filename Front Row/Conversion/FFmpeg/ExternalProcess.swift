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
            try runAndWait(executable, arguments: arguments)
        }.value
    }

    /// Runs the tool and blocks until it has finished and everything it printed has been read.
    ///
    /// Separate, and synchronous, because that is what it is: waiting on a process and on two
    /// pipes are all blocking calls, and they belong on a thread of their own rather than on one
    /// borrowed from the concurrency pool between suspensions.
    private static func runAndWait(_ executable: URL, arguments: [String]) throws -> Output {
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
        //
        // The handler says when it is done rather than being switched off. An empty read is
        // the pipe reaching its end, and waiting for it is what makes the collected output
        // complete: clearing a handler does not stop one already running, so a tool that
        // complains and exits at once could have its last words read after they had been
        // asked for - leaving the alert that explains the failure with a truncated message,
        // or none.
        let errorBuffer = DataBuffer()
        let errorFinished = DispatchSemaphore(value: 0)
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                errorFinished.signal()
                return
            }
            errorBuffer.append(data)
        }

        try process.run()

        let standardOutput = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        // Bounded, so a pipe that never reports its end cannot hold a conversion open. What
        // was collected by then is still worth showing.
        if errorFinished.wait(timeout: .now() + 5) == .timedOut {
            errorPipe.fileHandleForReading.readabilityHandler = nil
        }

        return Output(
            standardOutput: standardOutput,
            standardError: String(decoding: errorBuffer.value, as: UTF8.self),
            terminationStatus: process.terminationStatus
        )
    }
}
