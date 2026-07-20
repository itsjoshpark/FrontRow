//
//  SecurityScopedBookmarkProvider.swift
//  Front Row
//
//  Created by Joshua Park on 7/19/26.
//

import Foundation

/// The real `BookmarkProviding`, backed by AppKit's security-scoped bookmark API.
@MainActor
struct SecurityScopedBookmarkProvider: BookmarkProviding {

    /// `url` must have active security-scoped access, which is true right after it was chosen via
    /// an open panel or drag-and-drop, or while a `ScopedAccess` for it is alive.
    func makeBookmark(for url: URL) throws -> Data {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    func resolve(_ data: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil,
            bookmarkDataIsStale: &isStale)
        return (url, isStale)
    }

    func startAccess(to url: URL) -> ScopedAccess? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        return ScopedAccess(url: url) { $0.stopAccessingSecurityScopedResource() }
    }
}
