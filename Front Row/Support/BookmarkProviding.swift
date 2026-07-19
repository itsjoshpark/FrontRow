//
//  BookmarkProviding.swift
//  Front Row
//
//  Created by Joshua Park on 7/19/26.
//

import Foundation

/// Creates and resolves the security-scoped bookmarks that let the app reopen a user-selected file
/// after relaunch.
///
/// Abstracted so tests can drive resolution outcomes real bookmarks can't be made to produce on
/// demand, such as a stale bookmark or one resolving to a moved file.
@MainActor
protocol BookmarkProviding {
    func makeBookmark(for url: URL) throws -> Data
    func resolve(_ data: Data) throws -> (url: URL, isStale: Bool)
    func startAccess(to url: URL) -> ScopedAccess?
}
