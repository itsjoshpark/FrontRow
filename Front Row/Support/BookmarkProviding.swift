//
//  BookmarkProviding.swift
//  Front Row
//
//  Created by Joshua Park on 7/24/26.
//

import Foundation

/// What a bookmark says about its target without being resolved.
///
/// The path and volume are baked into the bookmark when it's created, so they can be read back
/// with the volume offline - unlike resolution, which fails. That's what lets a file on a
/// disconnected drive still be listed by name.
struct BookmarkMetadata: Equatable {
    var url: URL
    var volumeURL: URL?
    var volumeName: String?
}

/// Wraps security-scoped bookmark creation/resolution so `RecentDocumentsStore` can be tested
/// without the macOS App Sandbox's real user-selected-file grants, which a test process can't
/// obtain or exercise deterministically.
protocol BookmarkProviding {
    /// Creates bookmark data for `url`. `url` must currently have active security-scoped access.
    func bookmarkData(for url: URL) -> Data?

    /// Reads a bookmark's target from its own metadata, without resolving it.
    ///
    /// Used on the launch path, so it must never mount a volume, block on the network, or show
    /// UI: an entry on a disconnected drive still needs a name to display.
    func metadata(from data: Data) -> BookmarkMetadata?

    /// Resolves previously created bookmark data. Returns `nil` if it can no longer be resolved,
    /// e.g. because the file was deleted or permission was revoked.
    func resolveBookmark(_ data: Data) -> (url: URL, isStale: Bool)?

    /// Starts security-scoped access to a resolved URL. Returns whether access was granted.
    func startAccessingSecurityScopedResource(_ url: URL) -> Bool
}

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
