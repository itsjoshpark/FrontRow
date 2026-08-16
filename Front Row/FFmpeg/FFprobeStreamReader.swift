//
//  FFprobeStreamReader.swift
//  Front Row
//
//  Created by Joshua Park on 8/15/26.
//

import Foundation

/// Asks ffprobe what's inside a media file.
struct FFprobeStreamReader: Sendable {

    let ffprobe: URL

    func probe(_ url: URL) async throws -> ProbedMedia {
        let output = try await ExternalProcess.run(
            ffprobe, arguments: FFmpegArguments.probe(input: url))

        guard output.didSucceed else {
            throw FFmpegError.probeFailed(message: output.standardError)
        }

        do {
            return try JSONDecoder().decode(ProbedMedia.self, from: output.standardOutput)
        } catch {
            throw FFmpegError.probeFailed(message: error.localizedDescription)
        }
    }
}

/// Something went wrong out in ffmpeg-land.
enum FFmpegError: Error, Equatable {
    /// ffprobe couldn't read the file, or said something this app couldn't parse.
    case probeFailed(message: String)
    /// ffmpeg exited non-zero. The message is everything it wrote to standard error - kept whole
    /// because the alert hides it behind a disclosure, where there's no reason to truncate what
    /// someone might need to paste into a bug report.
    case conversionFailed(message: String)
    case cancelled
}
