//
//  RecentDocumentsStoreTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

@MainActor
struct RecentDocumentsStoreTests {

    private func makeDefaults(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    /// The bug this whole design exists for: a file on a NAS or external drive stops resolving the
    /// moment the volume goes away. Its entry - and the playback position inside it - must survive
    /// a relaunch in that state, and must still be there after a later write flushes the list.
    @Test
    func entriesOnADisconnectedVolumeSurviveRelaunch() {
        let defaults = makeDefaults(#function)
        let provider = FakeBookmarkProvider()
        let volumes = FakeMountedVolumesProvider()

        let networkVolume = URL(filePath: "/Volumes/NAS")
        let networkFile = URL(fileURLWithPath: "/Volumes/NAS/movie.mov")
        let localFile = URL(fileURLWithPath: "/tmp/local.mov")
        provider.volumeURLs[networkFile] = networkVolume
        provider.volumeNames[networkVolume] = "NAS"
        volumes.mount(networkVolume)

        var store = RecentDocumentsStore(
            defaults: defaults, bookmarkProvider: provider, mountedVolumes: volumes)
        store.noteRecentDocument(networkFile)
        store.setPosition(123, for: networkFile)

        // The volume goes away: the bookmark no longer resolves, and it's no longer mounted.
        provider.deletedURLs.insert(networkFile)
        volumes.unmount(networkVolume)

        store = RecentDocumentsStore(
            defaults: defaults, bookmarkProvider: provider, mountedVolumes: volumes)

        #expect(store.recentURLs.contains(networkFile))
        #expect(store.position(for: networkFile) == 123)

        // Opening something else rewrites the persisted list - the step that used to make the
        // loss permanent.
        store.noteRecentDocument(localFile)
        store = RecentDocumentsStore(
            defaults: defaults, bookmarkProvider: provider, mountedVolumes: volumes)

        #expect(store.recentURLs.contains(networkFile))
        #expect(store.position(for: networkFile) == 123)
    }

    /// A file that's genuinely gone stays listed too - only an explicit removal drops it, and that
    /// takes its position with it rather than leaving one behind to be misattributed.
    @Test
    func deletedFilesArePreservedUntilExplicitlyRemoved() {
        let defaults = makeDefaults(#function)
        let provider = FakeBookmarkProvider()
        let volumes = FakeMountedVolumesProvider()

        let deletedFile = URL(fileURLWithPath: "/tmp/deleted.mov")
        let survivingFile = URL(fileURLWithPath: "/tmp/surviving.mov")

        var store = RecentDocumentsStore(
            defaults: defaults, bookmarkProvider: provider, mountedVolumes: volumes)
        store.noteRecentDocument(deletedFile)
        store.noteRecentDocument(survivingFile)
        store.setPosition(42, for: deletedFile)
        store.setPosition(17, for: survivingFile)

        provider.deletedURLs.insert(deletedFile)

        store = RecentDocumentsStore(
            defaults: defaults, bookmarkProvider: provider, mountedVolumes: volumes)

        #expect(store.recentURLs.contains(deletedFile))

        store.removeRecentDocument(deletedFile)

        #expect(!store.recentURLs.contains(deletedFile))
        #expect(store.position(for: deletedFile) == nil)
        #expect(store.recentURLs.contains(survivingFile))
        #expect(store.position(for: survivingFile) == 17)
    }

    /// A failed open has to be able to name the drive that isn't there, so the volume lookup has to
    /// track the volume actually being mounted.
    @Test
    func anUnmountedVolumeIsNamedForTheFailedOpenAlert() {
        let defaults = makeDefaults(#function)
        let provider = FakeBookmarkProvider()
        let volumes = FakeMountedVolumesProvider()

        let externalVolume = URL(filePath: "/Volumes/Media")
        let externalFile = URL(fileURLWithPath: "/Volumes/Media/movie.mov")
        let localFile = URL(fileURLWithPath: "/tmp/local.mov")
        provider.volumeURLs[externalFile] = externalVolume
        provider.volumeNames[externalVolume] = "Media"
        volumes.mount(externalVolume)

        let store = RecentDocumentsStore(
            defaults: defaults, bookmarkProvider: provider, mountedVolumes: volumes)
        store.noteRecentDocument(externalFile)
        store.noteRecentDocument(localFile)

        #expect(store.unavailableVolumeName(for: externalFile) == nil)

        volumes.unmount(externalVolume)

        #expect(store.unavailableVolumeName(for: externalFile) == "Media")

        // A file on the boot volume is unaffected by another volume being ejected.
        #expect(store.unavailableVolumeName(for: localFile) == nil)
    }

    /// A URL that isn't tracked at all can't be judged unreachable - callers ask about files
    /// they've just tried to open, so blaming a drive would be worse than saying nothing.
    @Test
    func untrackedURLsNameNoUnavailableVolume() {
        let defaults = makeDefaults(#function)
        let store = RecentDocumentsStore(
            defaults: defaults, bookmarkProvider: FakeBookmarkProvider(),
            mountedVolumes: FakeMountedVolumesProvider())

        #expect(
            store.unavailableVolumeName(for: URL(fileURLWithPath: "/tmp/never-seen.mov")) == nil)
        #expect(
            store.unavailableVolumeName(for: URL(string: "https://example.com/stream.m3u8")!) == nil
        )
    }

    /// Reopening a file already in recents moves it to the front of the list; its saved position
    /// must move with it rather than being reset.
    @Test
    func reopeningARecentFilePreservesItsPosition() {
        let defaults = makeDefaults(#function)
        let provider = FakeBookmarkProvider()

        let file = URL(fileURLWithPath: "/tmp/movie.mov")
        let otherFile = URL(fileURLWithPath: "/tmp/other.mov")

        let store = RecentDocumentsStore(
            defaults: defaults, bookmarkProvider: provider,
            mountedVolumes: FakeMountedVolumesProvider())
        store.noteRecentDocument(file)
        store.setPosition(90, for: file)
        store.noteRecentDocument(otherFile)

        // Reopening `file` moves it back to the front of the list.
        store.noteRecentDocument(file)

        #expect(store.recentURLs.first == file)
        #expect(store.position(for: file) == 90)
    }

    /// A bookmark records a fully symlink-resolved path, so a file opened through a symlinked
    /// folder is filed under a URL the caller never has. Both must reach the same entry: otherwise
    /// its position is written into nothing, and reopening the file appends a duplicate that
    /// collides in the `id: \.self` lists that draw recents.
    @Test
    func aFileOpenedThroughASymlinkIsTrackedOnce() throws {
        let root = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }

        let realDirectory = root.appending(path: "real")
        try FileManager.default.createDirectory(
            at: realDirectory, withIntermediateDirectories: true)
        try Data().write(to: realDirectory.appending(path: "movie.mov"))
        try FileManager.default.createSymbolicLink(
            at: root.appending(path: "link"), withDestinationURL: realDirectory)

        let openedFile = root.appending(path: "link/movie.mov")
        let canonicalFile = openedFile.resolvingSymlinksInPath()
        #expect(openedFile != canonicalFile)

        let provider = FakeBookmarkProvider()
        provider.canonicalURLs[openedFile] = canonicalFile

        let store = RecentDocumentsStore(
            defaults: makeDefaults(#function), bookmarkProvider: provider,
            mountedVolumes: FakeMountedVolumesProvider())
        store.noteRecentDocument(openedFile)
        store.setPosition(75, for: openedFile)

        #expect(store.recentURLs == [canonicalFile])
        #expect(store.position(for: openedFile) == 75)
        #expect(store.position(for: canonicalFile) == 75)

        store.noteRecentDocument(openedFile)

        #expect(store.recentURLs == [canonicalFile])
        #expect(store.position(for: openedFile) == 75)
    }

    /// When a bookmark is resolved as stale and refreshed, the entry's saved position must
    /// survive the refresh rather than being dropped along with the old bookmark data.
    @Test
    func staleBookmarkRefreshPreservesPosition() {
        let defaults = makeDefaults(#function)
        let provider = FakeBookmarkProvider()

        let file = URL(fileURLWithPath: "/tmp/movie.mov")

        let store = RecentDocumentsStore(
            defaults: defaults, bookmarkProvider: provider,
            mountedVolumes: FakeMountedVolumesProvider())
        store.noteRecentDocument(file)
        store.setPosition(65, for: file)

        provider.staleURLs.insert(file)
        _ = store.startAccessingRecentDocument(file)

        #expect(store.position(for: file) == 65)
    }

    /// A bookmark tracks file identity, so a renamed file still opens - but the list is drawn from
    /// metadata captured when the bookmark was made, so it shows the old name until an open
    /// catches it up. That correction has to stick across a relaunch, and keep the position.
    @Test
    func openingAMovedFileUpdatesItsNameAndKeepsItsPosition() {
        let defaults = makeDefaults(#function)
        let provider = FakeBookmarkProvider()
        let volumes = FakeMountedVolumesProvider()

        let originalFile = URL(fileURLWithPath: "/tmp/movie.mov")
        let renamedFile = URL(fileURLWithPath: "/tmp/renamed.mov")

        var store = RecentDocumentsStore(
            defaults: defaults, bookmarkProvider: provider, mountedVolumes: volumes)
        store.noteRecentDocument(originalFile)
        store.setPosition(55, for: originalFile)

        // Renamed outside the app: the bookmark resolves to the new URL, and isn't flagged stale.
        provider.movedURLs[originalFile] = renamedFile

        #expect(store.startAccessingRecentDocument(originalFile) == renamedFile)
        #expect(store.recentURLs.contains(renamedFile))
        #expect(!store.recentURLs.contains(originalFile))
        #expect(store.position(for: renamedFile) == 55)

        store = RecentDocumentsStore(
            defaults: defaults, bookmarkProvider: provider, mountedVolumes: volumes)

        #expect(store.recentURLs.contains(renamedFile))
        #expect(store.position(for: renamedFile) == 55)
    }

    /// Opening a renamed file catches its entry up mid-open, so what gets noted afterwards is the
    /// new URL. That has to land on the existing entry - noting the name it opened under must move
    /// the file to the front rather than being dropped for matching nothing.
    @Test
    func notingAFileUnderItsNewNameMovesTheExistingEntry() {
        let provider = FakeBookmarkProvider()

        let originalFile = URL(fileURLWithPath: "/tmp/movie.mov")
        let renamedFile = URL(fileURLWithPath: "/tmp/renamed.mov")
        let otherFile = URL(fileURLWithPath: "/tmp/other.mov")

        let store = RecentDocumentsStore(
            defaults: makeDefaults(#function), bookmarkProvider: provider,
            mountedVolumes: FakeMountedVolumesProvider())
        store.noteRecentDocument(originalFile)
        store.setPosition(30, for: originalFile)
        store.noteRecentDocument(otherFile)

        provider.movedURLs[originalFile] = renamedFile
        _ = store.startAccessingRecentDocument(originalFile)

        store.noteRecentDocument(renamedFile)

        #expect(store.recentURLs == [renamedFile, otherFile])
        #expect(store.position(for: renamedFile) == 30)
    }
}
