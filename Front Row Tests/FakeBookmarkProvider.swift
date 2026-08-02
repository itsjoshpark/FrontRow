//
//  FakeBookmarkProvider.swift
//  Front Row Tests
//

import Foundation

@testable import Front_Row

/// A deterministic stand-in for security-scoped bookmarks in tests.
///
/// "Bookmark data" is just the URL's `absoluteString` encoded as UTF-8, so resolution is
/// reversible without touching the sandbox. Marking a URL as deleted makes its bookmark fail to
/// resolve, the same way a real bookmark fails once its file is gone - but its metadata keeps
/// reading back, because a real bookmark's recorded path survives the file it points at.
final class FakeBookmarkProvider: BookmarkProviding {

    var deletedURLs: Set<URL> = []
    var staleURLs: Set<URL> = []

    /// Bookmarks that now resolve somewhere else, standing in for a moved or renamed file.
    var movedURLs: [URL: URL] = [:]

    /// The volume each URL lives on. Anything absent is reported as being on the boot volume.
    var volumeURLs: [URL: URL] = [:]

    /// Display names for volumes, keyed by volume URL.
    var volumeNames: [URL: String] = [:]

    func bookmarkData(for url: URL) -> Data? {
        url.absoluteString.data(using: .utf8)
    }

    func metadata(from data: Data) -> BookmarkMetadata? {
        guard let url = decodeURL(from: data) else { return nil }

        let volumeURL = volumeURLs[url] ?? URL(filePath: "/")
        return BookmarkMetadata(
            url: url, volumeURL: volumeURL, volumeName: volumeNames[volumeURL])
    }

    func resolveBookmark(_ data: Data) -> (url: URL, isStale: Bool)? {
        guard let url = decodeURL(from: data) else { return nil }
        guard !deletedURLs.contains(url) else { return nil }
        return (movedURLs[url] ?? url, staleURLs.contains(url))
    }

    func startAccessingSecurityScopedResource(_ url: URL) -> Bool {
        true
    }

    private func decodeURL(from data: Data) -> URL? {
        guard let string = String(data: data, encoding: .utf8) else { return nil }
        return URL(string: string)
    }
}
