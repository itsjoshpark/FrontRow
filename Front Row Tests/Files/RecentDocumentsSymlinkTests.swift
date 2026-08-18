//
//  RecentDocumentsSymlinkTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

/// Reaching one file by two paths has to leave one entry.
///
/// Run against the real `SecurityScopedBookmarkProvider` rather than the fake. The store's
/// matching is built on what real bookmarks record, and a fake that answers with whatever it was
/// told cannot say whether the two agree - which is the whole risk here.
@MainActor
struct RecentDocumentsSymlinkTests {

    private func makeDefaults(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    /// A scratch directory whose path is already what both `resolvingSymlinksInPath()` and a
    /// bookmark call it.
    ///
    /// Not the temporary directory. That sits under `/var`, which is itself a link to
    /// `/private/var`, and the two disagree about which way to write it - a bookmark records
    /// `/private/var/…` while `resolvingSymlinksInPath()` answers `/var/…`. A store built there
    /// fails to match a file against itself, so every case below would fail without a symlink
    /// being involved at all.
    static func makeCanonicalRoot() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appending(path: "FrontRowTests-\(UUID().uuidString)")
    }

    /// The same file noted twice is one entry. Everything below rests on this working.
    @Test
    func theSameFileNotedTwiceIsOneEntry() throws {
        let defaults = makeDefaults(#function)
        let root = Self.makeCanonicalRoot()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let movie = root.appending(path: "movie.mov")
        try Data("front row".utf8).write(to: movie)

        let store = RecentDocumentsStore(
            defaults: defaults, bookmarkProvider: SecurityScopedBookmarkProvider())
        store.noteRecentDocument(movie)
        store.noteRecentDocument(movie)

        #expect(store.recentURLs.count == 1)
    }

    /// A directory symlink, where both paths end in the same file name.
    @Test
    func aFileReachedThroughASymlinkedFolderIsOneEntry() throws {
        let defaults = makeDefaults(#function)
        let root = Self.makeCanonicalRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let real = root.appending(path: "real")
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        let movie = real.appending(path: "movie.mov")
        try Data("front row".utf8).write(to: movie)
        try FileManager.default.createSymbolicLink(
            at: root.appending(path: "link"), withDestinationURL: real)

        let store = RecentDocumentsStore(
            defaults: defaults, bookmarkProvider: SecurityScopedBookmarkProvider())
        store.noteRecentDocument(movie)
        store.noteRecentDocument(root.appending(path: "link/movie.mov"))

        #expect(store.recentURLs.count == 1)
    }

    /// A symlink to the file itself, under a different name. The bookmark records the file it
    /// leads to, so both openings describe one file however the list chooses to name it.
    @Test
    func aFileReachedThroughARenamingSymlinkIsOneEntry() throws {
        let defaults = makeDefaults(#function)
        let root = Self.makeCanonicalRoot()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let movie = root.appending(path: "canonical.mov")
        try Data("front row".utf8).write(to: movie)
        let alias = root.appending(path: "alias.mov")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: movie)

        let store = RecentDocumentsStore(
            defaults: defaults, bookmarkProvider: SecurityScopedBookmarkProvider())
        store.noteRecentDocument(movie)
        store.noteRecentDocument(alias)

        #expect(store.recentURLs.count == 1)
    }

    /// The position follows the file rather than the path it was reached by, which is what keeps
    /// a resume point from being dropped when the same file is opened the other way.
    @Test
    func aPositionSavedByOnePathIsFoundByTheOther() throws {
        let defaults = makeDefaults(#function)
        let root = Self.makeCanonicalRoot()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let movie = root.appending(path: "canonical.mov")
        try Data("front row".utf8).write(to: movie)
        let alias = root.appending(path: "alias.mov")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: movie)

        let store = RecentDocumentsStore(
            defaults: defaults, bookmarkProvider: SecurityScopedBookmarkProvider())
        store.noteRecentDocument(movie)
        store.setPosition(321, for: movie)

        #expect(store.position(for: alias) == 321)
    }
}
