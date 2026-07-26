//
//  RecentDocumentsStoreTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

@MainActor
struct RecentDocumentsStoreTests {

    /// Deleting a file from disk should drop its recent-document entry and its saved position
    /// together, rather than leaking a position that could later be misattributed to another
    /// file.
    @Test
    func deletingAFileDropsItsPositionWithoutAffectingOthers() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let provider = FakeBookmarkProvider()

        let deletedFile = URL(fileURLWithPath: "/tmp/deleted.mov")
        let survivingFile = URL(fileURLWithPath: "/tmp/surviving.mov")

        var store = RecentDocumentsStore(defaults: defaults, bookmarkProvider: provider)
        store.noteRecentDocument(deletedFile)
        store.noteRecentDocument(survivingFile)
        store.setPosition(42, for: deletedFile)
        store.setPosition(17, for: survivingFile)

        // Simulate deletion: the bookmark for `deletedFile` no longer resolves.
        provider.deletedURLs.insert(deletedFile)

        // Relaunch: a fresh store reloads from the same persisted defaults.
        store = RecentDocumentsStore(defaults: defaults, bookmarkProvider: provider)

        #expect(!store.recentURLs.contains(deletedFile))
        #expect(store.recentURLs.contains(survivingFile))
        #expect(store.position(for: survivingFile) == 17)
        #expect(store.position(for: deletedFile) == nil)
    }

    /// Reopening a file already in recents moves it to the front of the list; its saved position
    /// must move with it rather than being reset.
    @Test
    func reopeningARecentFilePreservesItsPosition() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let provider = FakeBookmarkProvider()

        let file = URL(fileURLWithPath: "/tmp/movie.mov")
        let otherFile = URL(fileURLWithPath: "/tmp/other.mov")

        let store = RecentDocumentsStore(defaults: defaults, bookmarkProvider: provider)
        store.noteRecentDocument(file)
        store.setPosition(90, for: file)
        store.noteRecentDocument(otherFile)

        // Reopening `file` moves it back to the front of the list.
        store.noteRecentDocument(file)

        #expect(store.recentURLs.first == file)
        #expect(store.position(for: file) == 90)
    }

    /// When a bookmark is resolved as stale and refreshed, the entry's saved position must
    /// survive the refresh rather than being dropped along with the old bookmark data.
    @Test
    func staleBookmarkRefreshPreservesPosition() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let provider = FakeBookmarkProvider()

        let file = URL(fileURLWithPath: "/tmp/movie.mov")

        let store = RecentDocumentsStore(defaults: defaults, bookmarkProvider: provider)
        store.noteRecentDocument(file)
        store.setPosition(65, for: file)

        provider.staleURLs.insert(file)
        _ = store.startAccessingRecentDocument(file)

        #expect(store.position(for: file) == 65)
    }
}
