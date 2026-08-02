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

    /// Reachability drives presentation, so it has to track the volume actually being there.
    @Test
    func reachabilityFollowsWhetherTheVolumeIsMounted() {
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

        #expect(store.isReachable(externalFile))
        #expect(store.unavailableVolumeName(for: externalFile) == nil)

        volumes.unmount(externalVolume)

        #expect(!store.isReachable(externalFile))
        #expect(store.unavailableVolumeName(for: externalFile) == "Media")

        // A file on the boot volume is unaffected by another volume being ejected.
        #expect(store.isReachable(localFile))
        #expect(store.unavailableVolumeName(for: localFile) == nil)
    }

    /// A URL that isn't tracked at all can't be judged unreachable - callers use this for files
    /// they're about to open, so guessing "missing" would be worse than saying nothing.
    @Test
    func untrackedURLsCountAsReachable() {
        let defaults = makeDefaults(#function)
        let store = RecentDocumentsStore(
            defaults: defaults, bookmarkProvider: FakeBookmarkProvider(),
            mountedVolumes: FakeMountedVolumesProvider())

        #expect(store.isReachable(URL(fileURLWithPath: "/tmp/never-seen.mov")))
        #expect(store.isReachable(URL(string: "https://example.com/stream.m3u8")!))
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
}
