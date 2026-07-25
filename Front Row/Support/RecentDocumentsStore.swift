//
//  RecentDocumentsStore.swift
//  Front Row
//
//  Created by Joshua Park on 7/17/26.
//

import SwiftUI

/// Manages the recently opened files shown in File > Open Recent and the welcome window, along
/// with where playback last reached in each of them.
///
/// It keeps its own persisted list rather than using `NSDocumentController.recentDocumentURLs`,
/// which has no API to remove a single entry (only `clearRecentDocuments(_:)`).
///
/// Because the app is sandboxed read-only to user-selected files, access granted by the open
/// panel/drop doesn't survive relaunch. Each record therefore stores a security-scoped bookmark
/// (created while that access is still active) and resolves it when reopening the file.
///
/// Bookmarks are resolved lazily, at open time rather than at launch, because resolution can't
/// distinguish a deleted file from one on an unmounted volume - pruning eagerly would throw away
/// history for a drive that simply isn't plugged in.
///
/// Adds and full clears are mirrored to the system recents list so surfaces this doesn't draw
/// (e.g. the Dock menu) stay in sync. Single-entry removal has no such API, so a removed entry may
/// linger there until it ages out - an accepted cosmetic divergence, as is the double listing a
/// file picks up when it moves and its bookmark resolves to a new URL.
@MainActor
@Observable
final class RecentDocumentsStore {

    static let shared = RecentDocumentsStore()

    private static let defaultsKey = "RecentDocuments"

    /// Keys from when recents and playback positions were stored separately. Read by nothing now;
    /// removed on launch so they don't linger in the preferences file.
    private static let legacyDefaultsKeys = ["RecentDocumentBookmarks", "PlaybackPositions"]

    private let defaults: UserDefaults

    private let bookmarks: BookmarkProviding

    private let systemRecents: SystemRecentsMirroring

    private(set) var documents: [RecentDocument]

    init(
        defaults: UserDefaults = .standard,
        bookmarks: BookmarkProviding = SecurityScopedBookmarkProvider(),
        systemRecents: SystemRecentsMirroring = DocumentControllerRecents()
    ) {
        self.defaults = defaults
        self.bookmarks = bookmarks
        self.systemRecents = systemRecents

        let stored = defaults.data(forKey: Self.defaultsKey) ?? Data()
        documents = (try? JSONDecoder().decode([RecentDocument].self, from: stored)) ?? []

        for key in Self.legacyDefaultsKeys {
            defaults.removeObject(forKey: key)
        }
    }

    /// Resolves a URL the user just supplied - from the open panel, a drop, or Finder - into
    /// something playable, without yet committing it to the list.
    ///
    /// Returns `nil` if the file can't be reached - it was deleted, its volume is unmounted, or
    /// access was revoked - and for URLs that can't be bookmarked at all, such as remote ones.
    ///
    /// Matching `url` against a tracked record is a lookup heuristic, not identity: two records can
    /// list the same URL once a file has moved. Opening something the user picked out of the
    /// recents list must go through `prepareToReopen(_:)` so the id they picked is what's honored.
    func prepareToOpen(_ url: URL) -> PreparedDocument? {
        guard let existing = documents.first(where: { $0.url == url }) else {
            guard let bookmarkData = try? bookmarks.makeBookmark(for: url) else { return nil }
            return PreparedDocument(
                id: UUID(), url: url, bookmarkData: bookmarkData, savedPosition: nil, access: nil)
        }

        return prepare(existing)
    }

    /// Resolves a record the user picked out of the recents list, keyed by the id it was listed
    /// under. Returns `nil` for an unknown id, or if the file can't be reached.
    func prepareToReopen(_ id: RecentDocument.ID) -> PreparedDocument? {
        guard let existing = documents.first(where: { $0.id == id }) else { return nil }
        return prepare(existing)
    }

    /// Resolves a tracked record's bookmark and takes a grant on whatever it points at now,
    /// refreshing the bookmark in the returned document if it resolved stale.
    private func prepare(_ existing: RecentDocument) -> PreparedDocument? {
        guard let resolved = try? bookmarks.resolve(existing.bookmarkData),
            let access = bookmarks.startAccess(to: resolved.url)
        else { return nil }

        var bookmarkData = existing.bookmarkData
        if resolved.isStale, let refreshed = try? bookmarks.makeBookmark(for: resolved.url) {
            bookmarkData = refreshed
        }

        return PreparedDocument(
            id: existing.id, url: resolved.url, bookmarkData: bookmarkData,
            savedPosition: existing.position, access: access)
    }

    /// Commits a prepared document to the front of the list, once playback has actually started.
    func confirmOpened(_ prepared: PreparedDocument) {
        var document: RecentDocument
        if let index = documents.firstIndex(where: { $0.id == prepared.id }) {
            // Keep the live position rather than the snapshot taken at prepare time, and adopt the
            // URL and bookmark in case resolution moved them.
            document = documents.remove(at: index)
            document.url = prepared.url
            document.bookmarkData = prepared.bookmarkData
        } else {
            document = RecentDocument(
                id: prepared.id, url: prepared.url, bookmarkData: prepared.bookmarkData,
                position: prepared.savedPosition)
        }

        documents.insert(document, at: 0)
        trim()
        persist()

        systemRecents.note(prepared.url)
    }

    /// Removes a single record, e.g. because the file could no longer be opened. Does nothing for
    /// an id that was prepared but never committed.
    func remove(_ id: RecentDocument.ID) {
        guard documents.contains(where: { $0.id == id }) else { return }
        documents.removeAll { $0.id == id }
        persist()
    }

    func clear() {
        guard !documents.isEmpty else { return }
        documents.removeAll()
        persist()

        systemRecents.clearAll()
    }

    func setPosition(_ time: TimeInterval, for id: RecentDocument.ID) {
        update(id) { $0.position = time }
    }

    func clearPosition(for id: RecentDocument.ID) {
        update(id) { $0.position = nil }
    }

    /// Applies `change` and persists, skipping the write when nothing actually changed - pause,
    /// termination, and a periodic save can all land on the same position.
    private func update(_ id: RecentDocument.ID, _ change: (inout RecentDocument) -> Void) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }

        var document = documents[index]
        change(&document)
        guard document != documents[index] else { return }

        documents[index] = document
        persist()
    }

    /// Trims the list down to the user's Recent Items preference. Dropped records take their
    /// positions with them.
    private func trim() {
        let maxCount = max(0, systemRecents.maximumCount)
        guard documents.count > maxCount else { return }
        documents.removeSubrange(maxCount...)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(documents) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
