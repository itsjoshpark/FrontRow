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

    func bookmarkData(for url: URL) -> Data? {
        url.absoluteString.data(using: .utf8)
    }

    func resolveBookmark(_ data: Data) -> (url: URL, isStale: Bool)? {
        guard let string = String(data: data, encoding: .utf8), let url = URL(string: string)
        else { return nil }
        guard !deletedURLs.contains(url) else { return nil }
        return (url, staleURLs.contains(url))
    }

    func startAccessingSecurityScopedResource(_ url: URL) -> Bool {
        true
    }
}
