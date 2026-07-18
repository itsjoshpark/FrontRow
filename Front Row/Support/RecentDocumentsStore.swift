//
//  RecentDocumentsStore.swift
//  Front Row
//
//  Created by Joshua Park on 7/17/26.
//

import AppKit
import SwiftUI

/// Manages the recently opened files shown in File > Open Recent and the welcome window.
///
/// It keeps its own persisted list rather than using `NSDocumentController.recentDocumentURLs`,
/// which has no API to remove a single entry (only `clearRecentDocuments(_:)`).
///
/// Because the app is sandboxed read-only to user-selected files, access granted by the open
/// panel/drop doesn't survive relaunch. Each entry therefore stores a security-scoped bookmark
/// (created while that access is still active) and resolves it when reopening the file.
///
/// Adds and full clears are mirrored to `NSDocumentController` so system surfaces (e.g. the Dock
/// menu) stay in sync. Single-entry removal has no such API, so a removed entry may linger there
/// until it ages out - an accepted cosmetic divergence.
@MainActor
@Observable
final class RecentDocumentsStore {

    static let shared = RecentDocumentsStore()

    private static let defaultsKey = "RecentDocumentBookmarks"

    private struct Entry {
        let url: URL
        let bookmarkData: Data
    }

    private var entries: [Entry] = []

    var recentURLs: [URL] {
        entries.map(\.url)
    }

    private init() {
        entries = Self.loadPersistedEntries()
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
            let didStartAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            guard
                let bookmarkData = try? url.bookmarkData(
                    options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                    includingResourceValuesForKeys: nil, relativeTo: nil)
            else { return }
            entries.insert(Entry(url: url, bookmarkData: bookmarkData), at: 0)
        }

        let droppedEntries = trim()
        persist()

        for dropped in droppedEntries {
            PlaybackPositionStore.shared.clearPosition(for: dropped.url)
        }

        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    /// Removes a single entry, e.g. because the file could no longer be opened.
    func removeRecentDocument(_ url: URL) {
        entries.removeAll { $0.url == url }
        persist()
        PlaybackPositionStore.shared.clearPosition(for: url)
    }

    /// Empties the recent documents list.
    func clear() {
        let urls = entries.map(\.url)
        entries.removeAll()
        persist()

        for url in urls {
            PlaybackPositionStore.shared.clearPosition(for: url)
        }

        NSDocumentController.shared.clearRecentDocuments(nil)
    }

    /// Resolves a recent document's security-scoped bookmark and starts access to it.
    ///
    /// The caller is responsible for calling `stopAccessingSecurityScopedResource()` on the
    /// returned URL once done with it. Returns `nil` if `url` isn't a tracked recent document, or
    /// its bookmark can no longer be resolved (e.g. the file was deleted or permission was
    /// revoked).
    func startAccessingRecentDocument(_ url: URL) -> URL? {
        guard let index = entries.firstIndex(where: { $0.url == url }) else { return nil }

        var isStale = false
        guard
            let resolvedURL = try? URL(
                resolvingBookmarkData: entries[index].bookmarkData, options: [.withSecurityScope],
                relativeTo: nil, bookmarkDataIsStale: &isStale)
        else { return nil }

        guard resolvedURL.startAccessingSecurityScopedResource() else { return nil }

        if isStale,
            let refreshedData = try? resolvedURL.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil, relativeTo: nil)
        {
            entries[index] = Entry(url: resolvedURL, bookmarkData: refreshedData)
            persist()
        }

        return resolvedURL
    }

    /// Trims `entries` down to `NSDocumentController.shared.maximumRecentDocumentCount` and
    /// returns the entries that were dropped.
    @discardableResult
    private func trim() -> [Entry] {
        let maxCount = max(0, NSDocumentController.shared.maximumRecentDocumentCount)
        guard entries.count > maxCount else { return [] }
        let dropped = Array(entries[maxCount...])
        entries = Array(entries[..<maxCount])
        return dropped
    }

    private func persist() {
        let bookmarks = entries.map(\.bookmarkData)
        UserDefaults.standard.set(bookmarks, forKey: Self.defaultsKey)
    }

    private static func loadPersistedEntries() -> [Entry] {
        let bookmarks = UserDefaults.standard.array(forKey: defaultsKey) as? [Data] ?? []
        return bookmarks.compactMap { data in
            var isStale = false
            guard
                let url = try? URL(
                    resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil,
                    bookmarkDataIsStale: &isStale)
            else { return nil }
            return Entry(url: url, bookmarkData: data)
        }
    }
}
