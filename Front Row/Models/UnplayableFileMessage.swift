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
            localized: "“\(url.lastPathComponent)” isn't a format Front Row can play.",
            comment: "Alert message shown when a file exists but cannot be decoded"
        )
    }

    /// The same thing said about a file that couldn't be read at all, rather than one that was read
    /// and rejected.
    ///
    /// One whole sentence pair rather than the first sentence with a second glued on: word order
    /// differs between languages, and a translated opening followed by an untranslated addition -
    /// in a different script, for some of them - reads worse than either language on its own.
    static func text(for url: URL, mayBeDamaged: Bool) -> String {
        guard mayBeDamaged else { return text(for: url) }
        return String(
            localized:
                "“\(url.lastPathComponent)” isn't a format Front Row can play. The file may be damaged or incomplete.",
            comment: "Alert message shown when a file could not be read at all"
        )
    }
}
