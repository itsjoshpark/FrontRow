//
//  MediaLanguageName.swift
//  Front Row
//
//  Created by Joshua Park on 8/24/26.
//

import Foundation

/// Resolves a track's language tag to the name of that language.
enum MediaLanguageName {

    /// The tag a container writes when a track was never given a language.
    private static let undetermined = "und"

    /// The language's name in the viewer's language, or `nil` when the tag names no language.
    ///
    /// `und` is what an MP4 writes for a track nobody tagged, so it counts as no language at all
    /// rather than as a language called "Unknown language".
    static func name(forTag tag: String?) -> String? {
        guard let tag, !tag.isEmpty, tag != undetermined else { return nil }
        return Locale.current.localizedString(forIdentifier: tag) ?? tag
    }

    /// Whether the tag is the marker for a track that was never given a language.
    static func isUndetermined(_ tag: String?) -> Bool {
        tag == undetermined
    }
}
