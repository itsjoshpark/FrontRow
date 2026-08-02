//
//  SecurityScopedBookmarkProvider.swift
//  Front Row
//
//  Created by Joshua Park on 7/24/26.
//

import Foundation

/// The real `BookmarkProviding` implementation, backed by security-scoped bookmarks.
struct SecurityScopedBookmarkProvider: BookmarkProviding {

    func bookmarkData(for url: URL) -> Data? {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    func metadata(from data: Data) -> BookmarkMetadata? {
        guard
            let values = URL.resourceValues(
                forKeys: [.pathKey, .volumeURLKey, .volumeNameKey], fromBookmarkData: data),
            let path = values.path
        else { return nil }

        return BookmarkMetadata(
            url: URL(filePath: path), volumeURL: values.volume, volumeName: values.volumeName)
    }

    func resolveBookmark(_ data: Data) -> (url: URL, isStale: Bool)? {
        var isStale = false
        guard
            let url = try? URL(
                resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil,
                bookmarkDataIsStale: &isStale)
        else { return nil }
        return (url, isStale)
    }

    func startAccessingSecurityScopedResource(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }
}
