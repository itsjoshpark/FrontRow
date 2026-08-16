//
//  RecentDocumentsStore.swift
//  Front Row
//
//  Created by Joshua Park on 7/17/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Manages the recently opened files shown in File > Open Recent and the welcome window, along
/// with each file's saved playback position.
///
/// It keeps its own persisted list rather than using `NSDocumentController.recentDocumentURLs`,
/// which has no API to remove a single entry (only `clearRecentDocuments(_:)`).
///
/// Each entry stores a security-scoped bookmark rather than a path, and resolves it when reopening
/// the file. A bookmark tracks the file itself, so an entry survives the file being renamed or
/// moved - which `refreshEntry(at:resolvedURL:)` then writes back.
///
/// Loading deliberately reads each bookmark's *metadata* instead of resolving it. Resolution
/// depends on the file being reachable right now, so resolving at launch would drop every entry on
/// a sleeping NAS or an unplugged drive - and take their playback positions with them - as well as
/// risking a blocking mount during startup.
///
/// Entries are listed the same way whether or not their volume is mounted. A drive that looks
/// absent may be moments from answering, and an entry that opens fine shouldn't be marked as
/// broken; the volume is only consulted once an open has actually failed, to say why.
///
/// A playback position lives inside its entry, so a file and its resume point can never drift
/// apart: dropping an entry drops its position in the same step, and there's only ever one
/// identity to look a position up by.
///
/// Adds and full clears are mirrored to `NSDocumentController` so system surfaces (e.g. the Dock
/// menu) stay in sync. Single-entry removal has no such API, so a removed entry may linger there
/// until it ages out - an accepted cosmetic divergence.
@MainActor
@Observable
final class RecentDocumentsStore {

    static let shared = RecentDocumentsStore()

    private static let defaultsKey = "RecentDocuments"

    private struct Entry {
        var metadata: BookmarkMetadata
        var bookmarkData: Data
        var position: TimeInterval?

        var url: URL { metadata.url }
    }

    private struct StoredEntry: Codable {
        var bookmarkData: Data
        var position: TimeInterval?
    }

    private let defaults: UserDefaults
    private let bookmarkProvider: BookmarkProviding
    private let mountedVolumes: MountedVolumesProviding

    private var entries: [Entry] = []

    var recentURLs: [URL] {
        entries.map(\.url)
    }

    init(
        defaults: UserDefaults = .standard,
        bookmarkProvider: BookmarkProviding = SecurityScopedBookmarkProvider(),
        mountedVolumes: MountedVolumesProviding = MountedVolumes.shared
    ) {
        self.defaults = defaults
        self.bookmarkProvider = bookmarkProvider
        self.mountedVolumes = mountedVolumes
        entries = Self.loadPersistedEntries(defaults: defaults, bookmarkProvider: bookmarkProvider)
        trim()
    }

    /// Adds a URL to the front of the recent documents list, or moves it to the front if it's
    /// already present.
    ///
    /// `url` must currently have active security-scoped access (true right after it was chosen
    /// via an open panel or drag-and-drop, or after `startAccessingRecentDocument(_:)`) if it's
    /// not already tracked, since a bookmark needs to be created from it.
    func noteRecentDocument(_ url: URL) {
        if let existingIndex = index(of: url) {
            let entry = entries.remove(at: existingIndex)
            entries.insert(entry, at: 0)
        } else {
            guard let bookmarkData = bookmarkProvider.bookmarkData(for: url),
                let metadata = bookmarkProvider.metadata(from: bookmarkData)
            else { return }
            entries.insert(
                Entry(metadata: metadata, bookmarkData: bookmarkData, position: nil), at: 0)
        }

        trim()
        persist()

        // The entry's own URL, not the caller's, so system surfaces list the same path this store
        // keys by.
        NSDocumentController.shared.noteNewRecentDocumentURL(entries[0].url)
    }

    /// Removes a single entry. Nothing here drops one on its own - it goes when the user picks
    /// Remove from Recents, or dismisses a failed open that was diagnosed as gone. A file whose
    /// drive is merely disconnected keeps its entry, and the playback position inside it.
    func removeRecentDocument(_ url: URL) {
        guard let index = index(of: url) else { return }
        entries.remove(at: index)
        persist()
    }

    /// Empties the recent documents list.
    func clear() {
        entries.removeAll()
        persist()
        NSDocumentController.shared.clearRecentDocuments(nil)
    }

    /// Whether `url`'s volume is currently mounted.
    ///
    /// Deliberately doesn't touch the file. Reaching for one on a sleeping NAS or an unplugged
    /// drive can block, and this runs while drawing a list; the entry's recorded volume answers the
    /// same question without any I/O. An entry whose volume isn't known counts as reachable - not
    /// knowing isn't evidence of absence.
    private func isReachable(_ url: URL) -> Bool {
        guard url.isFileURL,
            let index = index(of: url),
            let volumeURL = entries[index].metadata.volumeURL
        else { return true }

        return mountedVolumes.mountedVolumeURLs.contains {
            $0.standardizedFileURL == volumeURL.standardizedFileURL
        }
    }

    /// The name of the disconnected volume `url` lives on, or `nil` if it's reachable.
    ///
    /// Only asked after an open has failed, to tell "the drive isn't here" apart from "the file is
    /// gone" - never to decide how the entry is drawn.
    func unavailableVolumeName(for url: URL) -> String? {
        guard !isReachable(url), let index = index(of: url) else { return nil }
        let metadata = entries[index].metadata
        return metadata.volumeName ?? metadata.volumeURL?.lastPathComponent
    }

    /// The saved playback position for `url`, if it's a tracked recent document with one.
    func position(for url: URL) -> TimeInterval? {
        guard let index = index(of: url) else { return nil }
        return entries[index].position
    }

    /// Saves a playback position for `url`. No-op if `url` isn't a tracked recent document.
    func setPosition(_ time: TimeInterval, for url: URL) {
        guard let index = index(of: url) else { return }
        entries[index].position = time
        persist()
    }

    /// Clears the saved playback position for `url`, if any.
    func clearPosition(for url: URL) {
        guard let index = index(of: url), entries[index].position != nil else { return }
        entries[index].position = nil
        persist()
    }

    /// Resolves a recent document's security-scoped bookmark and starts access to it.
    ///
    /// The caller is responsible for calling `stopAccessingSecurityScopedResource()` on the
    /// returned URL once done with it. Returns `nil` if `url` isn't a tracked recent document, or
    /// its bookmark can no longer be resolved (e.g. the file was deleted or permission was
    /// revoked).
    func startAccessingRecentDocument(_ url: URL) -> URL? {
        guard let index = index(of: url) else { return nil }

        guard
            let (resolvedURL, isStale) = bookmarkProvider.resolveBookmark(
                entries[index].bookmarkData)
        else { return nil }

        guard bookmarkProvider.startAccessingSecurityScopedResource(resolvedURL) else { return nil }

        // A bookmark tracks file identity rather than path, so a moved or renamed file resolves to
        // its new location - possibly without being flagged stale. Since the list is drawn from
        // bookmark metadata captured at creation time, this is the point where a drifted entry
        // catches up.
        if isStale || resolvedURL != entries[index].url {
            refreshEntry(at: index, resolvedURL: resolvedURL)
        }

        return resolvedURL
    }

    /// Finds the entry for `url`, tolerating a caller that holds a different but equivalent path.
    ///
    /// Entries are keyed by the path baked into their bookmark, which is fully symlink-resolved. A
    /// URL straight from the open panel or a drop isn't, so a file reached through a symlinked
    /// folder needs a second look before it counts as untracked. Only the miss pays for that -
    /// URLs taken from `recentURLs` are already resolved and match outright.
    private func index(of url: URL) -> Int? {
        if let index = entries.firstIndex(where: { $0.url == url }) { return index }

        let resolved = url.resolvingSymlinksInPath()
        guard resolved != url else { return nil }
        return entries.firstIndex { $0.url == resolved }
    }

    /// Re-derives an entry's bookmark and display metadata from where its file actually is now.
    private func refreshEntry(at index: Int, resolvedURL: URL) {
        guard let refreshedData = bookmarkProvider.bookmarkData(for: resolvedURL),
            let metadata = bookmarkProvider.metadata(from: refreshedData)
        else { return }

        entries[index].bookmarkData = refreshedData
        entries[index].metadata = metadata
        persist()
    }

    /// Trims `entries` down to `NSDocumentController.shared.maximumRecentDocumentCount`.
    private func trim() {
        let maxCount = max(0, NSDocumentController.shared.maximumRecentDocumentCount)
        guard entries.count > maxCount else { return }
        entries = Array(entries[..<maxCount])
    }

    private func persist() {
        let stored = entries.map {
            StoredEntry(bookmarkData: $0.bookmarkData, position: $0.position)
        }
        guard let data = try? PropertyListEncoder().encode(stored) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }

    private static func loadPersistedEntries(
        defaults: UserDefaults, bookmarkProvider: BookmarkProviding
    ) -> [Entry] {
        guard let data = defaults.data(forKey: defaultsKey),
            let stored = try? PropertyListDecoder().decode([StoredEntry].self, from: data)
        else { return [] }

        return stored.compactMap { record in
            guard let metadata = bookmarkProvider.metadata(from: record.bookmarkData) else {
                return nil
            }
            return Entry(
                metadata: metadata, bookmarkData: record.bookmarkData, position: record.position)
        }
    }
}

extension URL {
    /// An icon suitable for representing this URL in the Open Recent menu / welcome screen,
    /// whether it points to a local file or a remote resource.
    var recentDocumentIcon: NSImage {
        if isFileURL {
            return NSWorkspace.shared.icon(forFile: path(percentEncoded: false))
        }
        return NSWorkspace.shared.icon(for: .url)
    }
}
