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
                let process = Process()
                process.executableURL = ffmpeg
                process.arguments = arguments
                process.standardInput = FileHandle.nullDevice

                let progressPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = progressPipe
                process.standardError = errorPipe

                let lineBuffer = LineBuffer()
                progressPipe.fileHandleForReading.readabilityHandler = { handle in
                    for line in lineBuffer.lines(from: handle.availableData) {
                        if case .fraction(let fraction) = parser.event(for: line) {
                            onProgress(fraction)
                        }
                    }
                }

                let errorBuffer = DataBuffer()
                errorPipe.fileHandleForReading.readabilityHandler = { handle in
                    errorBuffer.append(handle.availableData)
                }

                guard box.adopt(process) else { throw FFmpegError.cancelled }
                try process.run()
                process.waitUntilExit()

                progressPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil

                if box.wasCancelled { throw FFmpegError.cancelled }

                guard process.terminationStatus == 0 else {
                    let message = String(decoding: errorBuffer.value, as: UTF8.self)
                    throw FFmpegError.conversionFailed(
                        message: message.trimmingCharacters(in: .whitespacesAndNewlines))
                }

                onProgress(1)
            }.value
        } onCancel: {
            box.cancel()
        }
    }
}
