//
//  RecentDocumentsStoreTests.swift
//  Front Row Tests
//
//  Created by Joshua Park on 7/19/26.
//

import Foundation
import Testing

@testable import Front_Row

@MainActor
struct RecentDocumentsStoreTests {

    private static let bookmarksKey = "RecentDocumentBookmarks"

    private let deletedFile = URL(filePath: "/tmp/deleted.mp4")

    /// Regression test: a file deleted between launches drops out of recents because its bookmark
    /// no longer resolves. Its saved position used to survive that, orphaned forever.
    @Test func discardsPositionsWithNoRecentEntry() {
        let defaults = TestDefaults()
        let positionStore = PlaybackPositionStore(defaults: defaults.suite)
        positionStore.setPosition(3843.5, for: deletedFile)

        // Bookmark data that can't resolve, standing in for the deleted file.
        defaults.suite.set([Data([0xDE, 0xAD, 0xBE, 0xEF])], forKey: Self.bookmarksKey)

        let store = RecentDocumentsStore(defaults: defaults.suite, positionStore: positionStore)

        #expect(store.recentURLs.isEmpty)
        #expect(positionStore.position(for: deletedFile) == nil)
    }

    /// The pruned list must be written back, not just dropped from memory.
    @Test func persistsPrunedBookmarkList() {
        let defaults = TestDefaults()
        defaults.suite.set([Data([0xDE, 0xAD, 0xBE, 0xEF])], forKey: Self.bookmarksKey)

        _ = RecentDocumentsStore(
            defaults: defaults.suite,
            positionStore: PlaybackPositionStore(defaults: defaults.suite))

        let persisted = defaults.suite.array(forKey: Self.bookmarksKey) as? [Data]
        #expect(persisted?.isEmpty == true)
    }

    @Test func startsEmptyWithNoStoredBookmarks() {
        let defaults = TestDefaults()
        let store = RecentDocumentsStore(
            defaults: defaults.suite,
            positionStore: PlaybackPositionStore(defaults: defaults.suite))

        #expect(store.recentURLs.isEmpty)
    }
}
