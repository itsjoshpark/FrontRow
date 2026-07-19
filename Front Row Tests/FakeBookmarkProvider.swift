//
//  FakeBookmarkProvider.swift
//  Front Row Tests
//
//  Created by Joshua Park on 7/19/26.
//

import Foundation

@testable import Front_Row

/// A `BookmarkProviding` whose resolution outcomes can be driven directly, so tests can produce
/// stale bookmarks, moved files, and revoked access - none of which real bookmarks can be made to
/// do on demand.
@MainActor
final class FakeBookmarkProvider: BookmarkProviding {

    enum Failure: Error {
        case refused
    }

    var failsToMakeBookmarks = false

    var unresolvable: Set<Data> = []

    var stale: Set<Data> = []

    var deniedAccess: Set<URL> = []

    private var resolutions: [Data: URL] = [:]

    private var bookmarkCount = 0

    func makeBookmark(for url: URL) throws -> Data {
        guard !failsToMakeBookmarks else { throw Failure.refused }

        bookmarkCount += 1
        let data = Data("bookmark-\(bookmarkCount)".utf8)
        resolutions[data] = url
        return data
    }

    func resolve(_ data: Data) throws -> (url: URL, isStale: Bool) {
        guard !unresolvable.contains(data), let url = resolutions[data] else {
            throw Failure.refused
        }
        return (url, stale.contains(data))
    }

    func startAccess(to url: URL) -> ScopedAccess? {
        guard !deniedAccess.contains(url) else { return nil }
        return ScopedAccess(url: url) { _ in }
    }

    /// Points an existing bookmark at a different URL, as if the file had been moved.
    func redirect(_ data: Data, to url: URL) {
        resolutions[data] = url
    }
}
