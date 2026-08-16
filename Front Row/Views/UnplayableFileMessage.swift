//
//  UnplayableFileMessage.swift
//  Front Row
//
//  Created by Joshua Park on 8/16/26.
//

import Foundation

/// The one sentence Front Row uses whenever a file simply can't be played.
///
/// Shared rather than written out at each call site so the two stay identical, which also keeps
/// them on a single String Catalog key - one that already carries translations in every language
/// the app ships.
enum UnplayableFileMessage {

    static func text(for url: URL) -> String {
        String(
            localized: "\"\(url.lastPathComponent)\" isn't a format Front Row can play.",
            comment: "Alert message shown when a file exists but cannot be decoded"
        )
    }

    /// The same sentence, plus the reason when the file couldn't even be read.
    static func text(for url: URL, mayBeDamaged: Bool) -> String {
        guard mayBeDamaged else { return text(for: url) }
        return text(for: url) + " "
            + String(
                localized: "The file may be damaged or incomplete.",
                comment: "Appended when a file could not be read at all, not merely not decoded"
            )
    }
}
