//
//  RecentDocument.swift
//  Front Row
//
//  Created by Joshua Park on 7/19/26.
//

import Foundation

/// A file the user has opened, everything the app remembers about it in one record.
///
/// Identity is `id`, not `url`: a file's URL changes when it moves and its bookmark is refreshed,
/// and the URL the user picked isn't always the one its bookmark resolves to. Keying the playback
/// position off a stable id instead means it can't be orphaned or attributed to the wrong file.
struct RecentDocument: Codable, Identifiable, Equatable {

    let id: UUID

    /// Where the file was last known to be. Refreshed when a stale bookmark resolves elsewhere.
    var url: URL

    var bookmarkData: Data

    /// Seconds into the file, or `nil` if it was never played or was played to the end.
    var position: TimeInterval?

    init(id: UUID = UUID(), url: URL, bookmarkData: Data, position: TimeInterval? = nil) {
        self.id = id
        self.url = url
        self.bookmarkData = bookmarkData
        self.position = position
    }
}
