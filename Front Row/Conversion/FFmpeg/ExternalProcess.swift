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

    /// Runs `executable`, giving up after `timeout`.
    ///
    /// The deadline is the caller's to set, because what counts as too long depends on what is
    /// being asked: reading a file on a network volume is slow in a way that listing encoders is
    /// not. Without one, a tool that never answers holds the file-opening path open for good.
    static func run(
        _ executable: URL,
        arguments: [String],
        timeout: Duration
    ) async throws -> Output {
        let box = ProcessBox()

        // Terminating the child is what unblocks the thread waiting on it; a task blocked in
        // `waitUntilExit()` cannot be cancelled out of.
        let watchdog = Task {
            try await Task.sleep(for: timeout)
            box.cancel()
        }
        defer { watchdog.cancel() }

        let result: Result<Output, any Error>
        do {
            result = .success(
                try await withTaskCancellationHandler {
                    try await Task.detached(priority: .userInitiated) {
                        try runAndWait(executable, arguments: arguments, box: box)
                    }.value
                } onCancel: {
                    box.cancel()
                }
            )
        } catch {
            result = .failure(error)
        }

        // Both the watchdog and a cancelled caller stop the child the same way, so which happened
        // is read from the surrounding task rather than from the box.
        if box.wasCancelled {
            throw Task.isCancelled ? FFmpegError.cancelled : FFmpegError.timedOut
        }
        return try result.get()
    }

    /// Runs the tool and blocks until it has finished and everything it printed has been read.
    ///
    /// Separate, and synchronous, because that is what it is: waiting on a process and on two
    /// pipes are all blocking calls, and they belong on a thread of their own rather than on one
    /// borrowed from the concurrency pool between suspensions.
    private static func runAndWait(
        _ executable: URL,
        arguments: [String],
        box: ProcessBox
    ) throws -> Output {
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

        guard try box.launch(process) else { throw FFmpegError.cancelled }

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
