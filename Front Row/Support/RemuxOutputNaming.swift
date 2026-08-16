//
//  RemuxOutputNaming.swift
//  Front Row
//
//  Created by Joshua Park on 8/15/26.
//

import Foundation

/// Picks the name a converted file gets.
enum RemuxOutputNaming {

    /// Where `movie.mkv` should be written as an MP4.
    ///
    /// Beside the original, and never over the top of anything: a second conversion lands as
    /// `movie 2.mp4`, following how the Finder numbers a copy rather than inventing a scheme.
    static func outputURL(for input: URL, exists: (URL) -> Bool) -> URL {
        let directory = input.deletingLastPathComponent()
        let name = input.deletingPathExtension().lastPathComponent

        let firstChoice = directory.appending(path: name).appendingPathExtension("mp4")
        guard exists(firstChoice) else { return firstChoice }

        // Bounded so a directory that claims everything exists can't spin here.
        for suffix in 2...999 {
            let candidate =
                directory
                .appending(path: "\(name) \(suffix)")
                .appendingPathExtension("mp4")
            if !exists(candidate) { return candidate }
        }
        return
            directory
            .appending(path: "\(name) \(UUID().uuidString)")
            .appendingPathExtension("mp4")
    }

    /// The same thing, against the real file system.
    static func outputURL(for input: URL) -> URL {
        outputURL(for: input) {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }
    }
}
