//
//  RecentDocumentsStoreTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

@MainActor
struct RecentDocumentsStoreTests {

    /// A bookmark that won't resolve means "not reachable right now", not "gone forever" - a file
    /// on a detached volume fails identically to a deleted one. Relaunching must therefore keep
    /// the entry and its position, leaving removal to the user.
    @Test
    func entriesSurviveRelaunchWhenTheirBookmarkCannotResolve() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let provider = FakeBookmarkProvider()

        let unreachableFile = URL(fileURLWithPath: "/tmp/unreachable.mov")
        let reachableFile = URL(fileURLWithPath: "/tmp/reachable.mov")

        var store = RecentDocumentsStore(defaults: defaults, bookmarkProvider: provider)
        store.noteRecentDocument(unreachableFile)
        store.noteRecentDocument(reachableFile)
        store.setPosition(42, for: unreachableFile)
        store.setPosition(17, for: reachableFile)

        // Simulate an unmounted volume: the bookmark for `unreachableFile` no longer resolves.
        provider.deletedURLs.insert(unreachableFile)

        // Relaunch: a fresh store reloads from the same persisted defaults.
        store = RecentDocumentsStore(defaults: defaults, bookmarkProvider: provider)

        #expect(store.recentURLs.contains(unreachableFile))
        #expect(store.recentURLs.contains(reachableFile))
        #expect(store.position(for: unreachableFile) == 42)
        #expect(store.position(for: reachableFile) == 17)
    }

    /// Loading must not resolve bookmarks: resolution can stall on an unreachable volume, and the
    /// store is built synchronously on the main actor the first time a window touches it.
    @Test
    func loadingNeverResolvesBookmarks() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let provider = FakeBookmarkProvider()

        var store = RecentDocumentsStore(defaults: defaults, bookmarkProvider: provider)
        store.noteRecentDocument(URL(fileURLWithPath: "/tmp/movie.mov"))
        store.noteRecentDocument(URL(fileURLWithPath: "/tmp/other.mov"))

        store = RecentDocumentsStore(defaults: defaults, bookmarkProvider: provider)

        #expect(store.recentURLs.count == 2)
        #expect(provider.resolveCount == 0)
    }

    /// Cancelling the "isn't available" prompt must leave the entry usable: once the volume is
    /// back, the same entry plays and resumes where it left off.
    @Test
    func anUnavailableDocumentBecomesAccessibleAgainOnceItsBookmarkResolves() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let provider = FakeBookmarkProvider()

        let file = URL(fileURLWithPath: "/tmp/movie.mov")

        let store = RecentDocumentsStore(defaults: defaults, bookmarkProvider: provider)
        store.noteRecentDocument(file)
        store.setPosition(75, for: file)

        provider.deletedURLs.insert(file)
        #expect(store.startAccessingRecentDocument(file) == .unavailable)
        #expect(store.recentURLs.contains(file))

        provider.deletedURLs.remove(file)
        #expect(store.startAccessingRecentDocument(file) == .granted(file))
        #expect(store.position(for: file) == 75)
    }

    /// A bookmark can resolve while access is still refused. That's an availability failure too,
    /// and must not cost the entry.
    @Test
    func deniedSecurityScopedAccessReportsUnavailableWithoutDroppingTheEntry() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let provider = FakeBookmarkProvider()

        let file = URL(fileURLWithPath: "/tmp/movie.mov")

        let store = RecentDocumentsStore(defaults: defaults, bookmarkProvider: provider)
        store.noteRecentDocument(file)
        store.setPosition(30, for: file)

        provider.accessDeniedURLs.insert(file)

        #expect(store.startAccessingRecentDocument(file) == .unavailable)
        #expect(store.recentURLs.contains(file))
        #expect(store.position(for: file) == 30)
    }

    /// A URL that was never tracked has ambient access already, so it must be distinguishable from
    /// one that's tracked but unreachable - only the latter warrants offering to forget it.
    @Test
    func startAccessingAnUntrackedURLReportsNotTracked() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let provider = FakeBookmarkProvider()

        let store = RecentDocumentsStore(defaults: defaults, bookmarkProvider: provider)

        #expect(
            store.startAccessingRecentDocument(URL(fileURLWithPath: "/tmp/untracked.mov"))
                == .notTracked)
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
