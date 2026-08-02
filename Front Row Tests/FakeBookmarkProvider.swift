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
/// resolve, the same way a real bookmark fails once its file is gone.
final class FakeBookmarkProvider: BookmarkProviding {

    var deletedURLs: Set<URL> = []
    var staleURLs: Set<URL> = []
    var accessDeniedURLs: Set<URL> = []

    /// How many times a bookmark has been resolved, so tests can assert that loading doesn't.
    private(set) var resolveCount = 0

    func bookmarkData(for url: URL) -> Data? {
        url.absoluteString.data(using: .utf8)
    }

    func resolveBookmark(_ data: Data) -> (url: URL, isStale: Bool)? {
        resolveCount += 1
        guard let url = url(fromBookmarkData: data) else { return nil }
        guard !deletedURLs.contains(url) else { return nil }
        return (url, staleURLs.contains(url))
    }

    /// Deliberately ignores `deletedURLs`: reading the path recorded in a bookmark doesn't depend
    /// on the file still being there, which is the whole point of the real implementation.
    func url(fromBookmarkData data: Data) -> URL? {
        guard let string = String(data: data, encoding: .utf8) else { return nil }
        return URL(string: string)
    }

    func startAccessingSecurityScopedResource(_ url: URL) -> Bool {
        !accessDeniedURLs.contains(url)
    }
}
