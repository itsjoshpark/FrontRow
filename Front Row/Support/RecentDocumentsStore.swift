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
/// A playback position lives inside its entry, so a file and its resume point can never drift
/// apart: dropping an entry (e.g. because its bookmark no longer resolves - the file was deleted)
/// drops its position in the same step, and there's only ever one identity to look a position up
/// by.
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
        var url: URL
        var bookmarkData: Data
        var position: TimeInterval?
    }

    private struct StoredEntry: Codable {
        var bookmarkData: Data
        var position: TimeInterval?
    }

    private let defaults: UserDefaults
    private let bookmarkProvider: BookmarkProviding

    private var entries: [Entry] = []

    var recentURLs: [URL] {
        entries.map(\.url)
    }

    init(
        defaults: UserDefaults = .standard,
        bookmarkProvider: BookmarkProviding = SecurityScopedBookmarkProvider()
    ) {
        self.defaults = defaults
        self.bookmarkProvider = bookmarkProvider
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
            guard let bookmarkData = bookmarkProvider.bookmarkData(for: url) else { return }
            entries.insert(Entry(url: url, bookmarkData: bookmarkData, position: nil), at: 0)
        }

        trim()
        persist()

        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    /// Removes a single entry, e.g. because the file could no longer be opened.
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

        if isStale, let refreshedData = bookmarkProvider.bookmarkData(for: resolvedURL) {
            entries[index].url = resolvedURL
            entries[index].bookmarkData = refreshedData
            persist()
        }

        return resolvedURL
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
            guard let (url, _) = bookmarkProvider.resolveBookmark(record.bookmarkData) else {
                return nil
            }
            return Entry(url: url, bookmarkData: record.bookmarkData, position: record.position)
        }
    }
}
