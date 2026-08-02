//
//  SecurityScopedBookmarkProviderTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

/// Pins the Foundation behaviour `RecentDocumentsStore` is built on. Everything else about the
/// store is tested against `FakeBookmarkProvider`, which can't answer whether real bookmarks
/// actually behave this way - and the store is wrong in a way no fake would reveal if they don't.
struct SecurityScopedBookmarkProviderTests {

    /// Entries are listed by reading each bookmark's recorded path instead of resolving it, so a
    /// file on a detached volume stays listed. That rests on the path still reading back once
    /// resolution has stopped working. A deleted file stands in for an unmounted one - both fail
    /// resolution identically.
    @Test
    func metadataIsReadableAfterTheFileIsGone() throws {
        let provider = SecurityScopedBookmarkProvider()

        // A name needing percent-encoding, so reading the path back has to decode it the same way
        // `lastPathComponent` does.
        let file = URL.temporaryDirectory.appending(path: "réal môvie \(UUID().uuidString).mov")
        try Data("front row".utf8).write(to: file)

        let bookmarkData = try #require(provider.bookmarkData(for: file))

        // Compared against the bookmark's own earlier reading rather than the URL it was made
        // from: a bookmark records the canonical path, so a direct comparison would be testing
        // canonicalization instead of survival.
        let whileFileExists = try #require(provider.metadata(from: bookmarkData))
        #expect(whileFileExists.url.lastPathComponent == file.lastPathComponent)

        try FileManager.default.removeItem(at: file)

        #expect(provider.resolveBookmark(bookmarkData) == nil)
        #expect(provider.metadata(from: bookmarkData)?.url == whileFileExists.url)
    }

    /// A bookmark records the fully symlink-resolved path, not the one it was created from. This
    /// is why the store can't match entries against a caller's URL directly - a file opened
    /// through a symlinked folder would otherwise look untracked, losing its playback position and
    /// gaining a duplicate entry.
    @Test
    func metadataRecordsTheSymlinkResolvedPath() throws {
        let provider = SecurityScopedBookmarkProvider()

        let root = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }

        let realDirectory = root.appending(path: "real")
        try FileManager.default.createDirectory(
            at: realDirectory, withIntermediateDirectories: true)
        try Data("front row".utf8).write(to: realDirectory.appending(path: "movie.mov"))
        try FileManager.default.createSymbolicLink(
            at: root.appending(path: "link"), withDestinationURL: realDirectory)

        let openedThroughSymlink = root.appending(path: "link/movie.mov")
        let bookmarkData = try #require(provider.bookmarkData(for: openedThroughSymlink))
        let recordedPath = try #require(provider.metadata(from: bookmarkData)).url
            .path(percentEncoded: false)

        #expect(recordedPath.contains("/real/"))
        #expect(!recordedPath.contains("/link/"))
    }

    /// Naming the drive a file is waiting on depends on the volume coming back from the bookmark
    /// itself, since the volume can't be asked once it's detached.
    @Test
    func metadataCarriesTheVolumeWithoutResolving() throws {
        let provider = SecurityScopedBookmarkProvider()

        let file = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")
        try Data("front row".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let bookmarkData = try #require(provider.bookmarkData(for: file))
        let metadata = try #require(provider.metadata(from: bookmarkData))

        #expect(metadata.volumeURL != nil)
        #expect(metadata.volumeName != nil)
    }
}
