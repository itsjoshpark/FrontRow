//
//  MediaRemuxer.swift
//  Front Row
//
//  Created by Joshua Park on 8/15/26.
//

import Foundation

/// Runs the ffmpeg conversion, reporting how far along it is.
struct MediaRemuxer: Sendable {

    let tools: FFmpegTools

    /// Converts `input` into `output`, calling `onProgress` with a 0-to-1 fraction as ffmpeg works.
    ///
    /// Cancelling the surrounding task terminates ffmpeg and throws `FFmpegError.cancelled`. The
    /// half-written output is the caller's to clean up.
    func remux(
        input: URL,
        output: URL,
        recipe: RemuxRecipe,
        duration: TimeInterval?,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let arguments = FFmpegArguments.remux(
            input: input,
            output: output,
            recipe: recipe,
            aacEncoder: tools.aacEncoder
        )
        let parser = FFmpegProgressParser(duration: duration)
        let box = ProcessBox()
        let ffmpeg = tools.ffmpeg

        try await withTaskCancellationHandler {
            // Detached so ffmpeg is stopped by `box.cancel()` rather than by the task being torn
            // out from under a blocked `waitUntilExit()`.
            try await Task.detached(priority: .userInitiated) {
                try runAndWait(
                    ffmpeg: ffmpeg,
                    arguments: arguments,
                    parser: parser,
                    box: box,
                    onProgress: onProgress
                )
            }.value
        } onCancel: {
            box.cancel()
        }
    }

    /// Runs ffmpeg and blocks until it has finished and both its pipes have been read.
    ///
    /// Separate, and synchronous, because that is what it is: waiting on a process and on two
    /// pipes are all blocking calls, and they belong on a thread of their own rather than on one
    /// borrowed from the concurrency pool between suspensions.
    private func runAndWait(
        ffmpeg: URL,
        arguments: [String],
        parser: FFmpegProgressParser,
        box: ProcessBox,
        onProgress: @escaping @Sendable (Double) -> Void
    ) throws {
        let process = Process()
        process.executableURL = ffmpeg
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice

        let progressPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = progressPipe
        process.standardError = errorPipe

        // An empty read is the pipe reaching its end, and waiting for it is what makes each side
        // complete: clearing a handler does not stop one already running, so a tool that complains
        // and exits at once could have its last words read after they had been asked for.
        let lineBuffer = LineBuffer()
        let progressFinished = DispatchSemaphore(value: 0)
        progressPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                progressFinished.signal()
                return
            }
            for line in lineBuffer.lines(from: data) {
                if case .fraction(let fraction) = parser.event(for: line) {
                    onProgress(fraction)
                }
            }
        }

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
        process.waitUntilExit()

        // Bounded, so a pipe that never reports its end cannot hold a conversion open. What was
        // collected by then is still worth showing.
        if errorFinished.wait(timeout: .now() + 5) == .timedOut {
            errorPipe.fileHandleForReading.readabilityHandler = nil
        }
        if progressFinished.wait(timeout: .now() + 5) == .timedOut {
            progressPipe.fileHandleForReading.readabilityHandler = nil
        }

        if box.wasCancelled { throw FFmpegError.cancelled }

        guard process.terminationStatus == 0 else {
            let message = String(decoding: errorBuffer.value, as: UTF8.self)
            throw FFmpegError.conversionFailed(
                message: message.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        onProgress(1)
    }
}
