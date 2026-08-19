//
//  RemuxOutputNaming.swift
//  Front Row
//
//  Created by Joshua Park on 8/15/26.
//

import Foundation

/// Picks the name a converted file gets.
enum RemuxOutputNaming {

    /// The extension ffmpeg writes under until the conversion has finished.
    static let workingFileExtension = "part"

    /// Where `movie.mkv` should be written as an MP4.
    ///
    /// Beside the original, and never over the top of anything: a second conversion lands as
    /// `movie 2.mp4`, following how the Finder numbers a copy rather than inventing a scheme.
    static func outputURL(for input: URL, exists: (URL) -> Bool) -> URL {
        let directory = input.deletingLastPathComponent()
        let name = input.deletingPathExtension().lastPathComponent

        // A leftover working file counts as taken. It belongs to a run that died, and it is the
        // user's to look at and delete - a new conversion must neither write over it nor adopt the
        // name it is holding for.
        func isTaken(_ candidate: URL) -> Bool {
            exists(candidate) || exists(workingURL(besides: candidate))
        }

        let firstChoice = directory.appending(path: name).appendingPathExtension("mp4")
        guard isTaken(firstChoice) else { return firstChoice }

        // Bounded so a directory that claims everything exists can't spin here.
        for suffix in 2...999 {
            let candidate =
                directory
                .appending(path: "\(name) \(suffix)")
                .appendingPathExtension("mp4")
            if !isTaken(candidate) { return candidate }
        }
        return
            directory
            .appending(path: "\(name) \(UUID().uuidString)")
            .appendingPathExtension("mp4")
    }

    /// The scratch path beside `output` that ffmpeg writes into.
    ///
    /// The conversion is only moved to its real name once it has finished, which means a failed or
    /// cancelled run never leaves half a film under a name that looks playable, and the move
    /// refuses to replace anything that appeared at the destination in the meantime. Same
    /// directory, so the move is a rename rather than a copy.
    ///
    /// Visible, and named for the file it is becoming. A run the app never got to tidy up - a crash,
    /// a power cut - leaves something the user can find and throw away, which a hidden name does
    /// not; and `.part` is an extension nothing opens, so a half film cannot be played by mistake.
    /// ffmpeg is told its output format outright, since the extension no longer names one.
    static func workingURL(besides output: URL) -> URL {
        output.appendingPathExtension(workingFileExtension)
    }

    /// The same thing, against the real file system.
    static func outputURL(for input: URL) -> URL {
        outputURL(for: input) {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }
    }
}
