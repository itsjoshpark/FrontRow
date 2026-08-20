//
//  FFprobeStreamReader.swift
//  Front Row
//
//  Created by Joshua Park on 8/15/26.
//

import Foundation

/// Asks ffprobe what's inside a media file.
struct FFprobeStreamReader: Sendable {

    /// Long enough for a large file on a slow volume, short enough that a tool which will never
    /// answer doesn't hold the file open indefinitely.
    static let timeout: Duration = .seconds(60)

    let ffprobe: URL

    func probe(_ url: URL) async throws -> ProbedMedia {
        let output = try await ExternalProcess.run(
            ffprobe, arguments: FFmpegArguments.probe(input: url), timeout: Self.timeout)

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
