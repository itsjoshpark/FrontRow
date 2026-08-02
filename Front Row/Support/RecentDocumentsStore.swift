//
//  RecentDocumentsStore.swift
//  Front Row
//
//  Created by Joshua Park on 7/17/26.
//

import AppKit
import SwiftUI

/// Manages the recently opened files shown in File > Open Recent and the welcome window, along
/// with each file's saved playback position.
///
/// It keeps its own persisted list rather than using `NSDocumentController.recentDocumentURLs`,
/// which has no API to remove a single entry (only `clearRecentDocuments(_:)`).
///
/// Because the app is sandboxed read-only to user-selected files, access granted by the open
/// panel/drop doesn't survive relaunch. Each entry therefore stores a security-scoped bookmark
/// (created while that access is still active) and resolves it when reopening the file.
///
/// Loading deliberately reads each bookmark's *metadata* instead of resolving it. Resolution
/// depends on the file being reachable right now, so resolving at launch would drop every entry on
/// a sleeping NAS or an unplugged drive - and take their playback positions with them - as well as
/// risking a blocking mount during startup. Reachability decides how an entry is displayed, never
/// whether it exists.
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
        if let existingIndex = entries.firstIndex(where: { $0.url == url }) {
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

        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    /// Removes a single entry. Only ever called because the user asked: an entry that can't be
    /// opened right now stays put, since the reason is often temporary.
    func removeRecentDocument(_ url: URL) {
        entries.removeAll { $0.url == url }
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
    /// Deliberately doesn't touch the file. Without an active bookmark the sandbox denies access
    /// to it, so asking the filesystem would report every recent document as missing; the entry's
    /// recorded volume can be checked without any such access. An entry whose volume isn't known
    /// counts as reachable - not knowing isn't evidence of absence.
    func isReachable(_ url: URL) -> Bool {
        guard url.isFileURL,
            let entry = entries.first(where: { $0.url == url }),
            let volumeURL = entry.metadata.volumeURL
        else { return true }

        return mountedVolumes.mountedVolumeURLs.contains {
            $0.standardizedFileURL == volumeURL.standardizedFileURL
        }
    }

    /// The name of the disconnected volume `url` lives on, or `nil` if it's reachable.
    func unavailableVolumeName(for url: URL) -> String? {
        guard !isReachable(url), let entry = entries.first(where: { $0.url == url }) else {
            return nil
        }
        return entry.metadata.volumeName ?? entry.metadata.volumeURL?.lastPathComponent
    }

    /// The saved playback position for `url`, if it's a tracked recent document with one.
    func position(for url: URL) -> TimeInterval? {
        entries.first { $0.url == url }?.position
    }

    /// Saves a playback position for `url`. No-op if `url` isn't a tracked recent document.
    func setPosition(_ time: TimeInterval, for url: URL) {
        guard let index = entries.firstIndex(where: { $0.url == url }) else { return }
        entries[index].position = time
        persist()
    }

    /// Clears the saved playback position for `url`, if any.
    func clearPosition(for url: URL) {
        guard let index = entries.firstIndex(where: { $0.url == url }),
            entries[index].position != nil
        else { return }
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
        guard let index = entries.firstIndex(where: { $0.url == url }) else { return nil }

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
