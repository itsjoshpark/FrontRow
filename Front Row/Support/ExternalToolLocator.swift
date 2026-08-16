//
//  ExternalToolLocator.swift
//  Front Row
//
//  Created by Joshua Park on 8/15/26.
//

import Foundation

/// Where ffmpeg and ffprobe were found, and which AAC encoder the build offers.
struct FFmpegTools: Equatable, Sendable {
    var ffmpeg: URL
    var ffprobe: URL
    /// `aac_at` where ffmpeg was built against AudioToolbox, otherwise ffmpeg's own `aac`.
    var aacEncoder: String = "aac"
}

/// Answers whether a path is something that can be run.
///
/// Behind a protocol so the search order can be tested without depending on what happens to be
/// installed on the machine running the tests.
protocol ExecutableProbing: Sendable {
    func isExecutable(atPath path: String) -> Bool
}

struct FileManagerExecutableProbe: ExecutableProbing {
    func isExecutable(atPath path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: path)
    }
}

/// Finds ffmpeg and ffprobe on disk.
///
/// The search is a fixed list of directories rather than `PATH`: an app launched from the Finder
/// inherits a bare `PATH` that contains none of the places a package manager installs into.
struct ExternalToolLocator: Sendable {

    /// Homebrew on Apple Silicon, Homebrew on Intel, then MacPorts.
    static let searchPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/opt/local/bin"]

    var probe: any ExecutableProbing = FileManagerExecutableProbe()
    var searchPaths: [String] = ExternalToolLocator.searchPaths

    /// Whether Homebrew is installed, which decides where the "no ffmpeg" alert sends the user.
    func hasHomebrew() -> Bool {
        locate("brew") != nil
    }

    /// Both tools, or `nil` if either is missing - ffmpeg alone is no use, since nothing should be
    /// converted before the streams have been checked.
    func locateFFmpeg() -> FFmpegTools? {
        guard let ffmpeg = locate("ffmpeg"), let ffprobe = locate("ffprobe") else { return nil }
        return FFmpegTools(ffmpeg: ffmpeg, ffprobe: ffprobe)
    }

    func locate(_ toolName: String) -> URL? {
        for directory in searchPaths {
            let path = directory + "/" + toolName
            if probe.isExecutable(atPath: path) {
                return URL(filePath: path)
            }
        }
        return nil
    }

    /// Finds the tools and asks ffmpeg which AAC encoder it was built with.
    func resolveFFmpeg() async -> FFmpegTools? {
        guard var tools = locateFFmpeg() else { return nil }
        tools.aacEncoder = await Self.preferredAACEncoder(ffmpeg: tools.ffmpeg)
        return tools
    }

    /// Apple's AudioToolbox encoder where the build has it, which is what the README has always
    /// recommended; ffmpeg's built-in encoder otherwise.
    static func preferredAACEncoder(ffmpeg: URL) async -> String {
        guard
            let output = try? await ExternalProcess.run(
                ffmpeg, arguments: FFmpegArguments.encoders),
            String(decoding: output.standardOutput, as: UTF8.self).contains("aac_at")
        else { return "aac" }
        return "aac_at"
    }
}
