//
//  RecentDocumentsStoreTests.swift
//  Front Row Tests
//
//  Created by Joshua Park on 7/19/26.
//

import AppKit
import Foundation
import Testing

@testable import Front_Row

@MainActor
struct RecentDocumentsStoreTests {

    private static let documentsKey = "RecentDocuments"

    private let fileA = URL(filePath: "/tmp/a.mp4")
    private let fileB = URL(filePath: "/tmp/b.mp4")

    private let defaults = TestDefaults()
    private let bookmarks = FakeBookmarkProvider()
    private let systemRecents = FakeSystemRecents()

    /// The cap is pinned rather than read from the Recent Items preference, which is a user setting
    /// and can legitimately be as low as zero on the machine running the tests.
    private func makeStore(maximumCount: Int = 10) -> RecentDocumentsStore {
        systemRecents.maximumCount = maximumCount
        return RecentDocumentsStore(
            defaults: defaults.suite, bookmarks: bookmarks, systemRecents: systemRecents)
    }

    /// Opens `url` end to end, the way `openFileAndPresent` does on success.
    @discardableResult
    private func open(_ url: URL, in store: RecentDocumentsStore) -> PreparedDocument? {
        guard let prepared = store.prepareToOpen(url) else { return nil }
        store.confirmOpened(prepared)
        return prepared
    }

    /// Reopens a tracked record by id, the way `openRecentDocumentAndPresent` does.
    @discardableResult
    private func reopen(_ id: RecentDocument.ID, in store: RecentDocumentsStore)
        -> PreparedDocument?
    {
        guard let prepared = store.prepareToReopen(id) else { return nil }
        store.confirmOpened(prepared)
        return prepared
    }

    // MARK: - Prepare and confirm

    @Test func preparingDoesNotTouchTheList() throws {
        let store = makeStore()

        let prepared = try #require(store.prepareToOpen(fileA))

        #expect(prepared.url == fileA)
        #expect(prepared.savedPosition == nil)
        #expect(store.documents.isEmpty)
        #expect(defaults.suite.data(forKey: Self.documentsKey) == nil)
    }

    @Test func confirmingInsertsAtFrontAndPersists() {
        let store = makeStore()

        open(fileA, in: store)
        open(fileB, in: store)

        #expect(store.documents.map(\.url) == [fileB, fileA])
        #expect(makeStore().documents.map(\.url) == [fileB, fileA])
    }

    /// The failed-open path: nothing was committed, so removing the prepared id is a no-op.
    @Test func abandoningAPreparedDocumentLeavesNoTrace() throws {
        let store = makeStore()
        let prepared = try #require(store.prepareToOpen(fileA))

        store.remove(prepared.id)

        #expect(store.documents.isEmpty)
        #expect(defaults.suite.data(forKey: Self.documentsKey) == nil)
    }

    @Test func reopeningMovesToFrontWithoutDuplicating() {
        let store = makeStore()
        open(fileA, in: store)
        open(fileB, in: store)

        open(fileA, in: store)

        #expect(store.documents.map(\.url) == [fileA, fileB])
    }

    @Test func preparingAnUnbookmarkableURLFails() {
        let store = makeStore()
        bookmarks.failsToMakeBookmarks = true

        #expect(store.prepareToOpen(fileA) == nil)
    }

    @Test func preparingAnUnresolvableDocumentFails() throws {
        let store = makeStore()
        let prepared = try #require(open(fileA, in: store))

        bookmarks.unresolvable = [prepared.bookmarkData]

        #expect(store.prepareToOpen(fileA) == nil)
    }

    // MARK: - Identity

    /// Regression test: `FileOpening` used to record the URL the caller asked for while `PlayEngine`
    /// held the bookmark-resolved one. Reopening now yields the resolved URL under the same id.
    @Test func reopeningReusesTheIDAndReturnsTheResolvedURL() throws {
        let store = makeStore()
        let first = try #require(open(fileA, in: store))

        bookmarks.redirect(first.bookmarkData, to: fileB)
        let second = try #require(store.prepareToOpen(fileA))

        #expect(second.id == first.id)
        #expect(second.url == fileB)
    }

    /// The whole point of UUID identity: a file that moves keeps its position.
    @Test func positionSurvivesAResolvedURLChange() throws {
        let store = makeStore()
        let first = try #require(open(fileA, in: store))
        store.setPosition(120, for: first.id)

        bookmarks.redirect(first.bookmarkData, to: fileB)
        let second = try #require(store.prepareToOpen(fileA))

        #expect(second.savedPosition == 120)
        #expect(store.documents.count == 1)
    }

    /// Regression test: a moved file leaves two records listing the same URL, and the URL-matching
    /// lookup can only ever find the first. Reopening has to follow the id the user picked.
    @Test func reopeningFollowsTheIDWhenTwoRecordsShareAURL() throws {
        let store = makeStore()
        let a = try #require(open(fileA, in: store))
        store.setPosition(11, for: a.id)
        let b = try #require(open(fileB, in: store))
        store.setPosition(22, for: b.id)

        // fileB moves onto fileA's path, so both records now list fileA.
        bookmarks.redirect(b.bookmarkData, to: fileA)
        let moved = try #require(reopen(b.id, in: store))
        try #require(store.documents.filter { $0.url == fileA }.count == 2)

        let reopened = try #require(store.prepareToReopen(a.id))

        #expect(reopened.id == a.id)
        #expect(reopened.savedPosition == 11)
        // The URL-matching path can't tell the two apart - it finds whichever is nearer the front.
        #expect(store.prepareToOpen(fileA)?.id == moved.id)
    }

    @Test func reopeningAnUnknownIDFails() {
        let store = makeStore()

        #expect(store.prepareToReopen(UUID()) == nil)
    }

    @Test func staleBookmarkIsRefreshedInPlace() throws {
        let store = makeStore()
        let first = try #require(open(fileA, in: store))
        store.setPosition(90, for: first.id)

        bookmarks.stale = [first.bookmarkData]
        bookmarks.redirect(first.bookmarkData, to: fileB)
        let second = try #require(open(fileA, in: store))

        #expect(store.documents.count == 1)
        let document = try #require(store.documents.first)
        #expect(document.id == first.id)
        #expect(document.url == fileB)
        #expect(document.bookmarkData != first.bookmarkData)
        #expect(document.position == 90)
        #expect(second.savedPosition == 90)
    }

    // MARK: - Positions

    @Test func positionsRoundTripByID() throws {
        let store = makeStore()
        let a = try #require(open(fileA, in: store))
        let b = try #require(open(fileB, in: store))

        store.setPosition(10, for: a.id)
        store.setPosition(20, for: b.id)

        #expect(makeStore().documents.first(where: { $0.id == a.id })?.position == 10)
        #expect(makeStore().documents.first(where: { $0.id == b.id })?.position == 20)
    }

    @Test func clearingAPositionLeavesTheDocument() throws {
        let store = makeStore()
        let a = try #require(open(fileA, in: store))
        store.setPosition(10, for: a.id)

        store.clearPosition(for: a.id)

        #expect(store.documents.count == 1)
        #expect(store.documents.first?.position == nil)
    }

    @Test func settingAPositionForAnUnknownIDIsIgnored() {
        let store = makeStore()

        store.setPosition(10, for: UUID())

        #expect(store.documents.isEmpty)
    }

    /// Pause, termination, and a periodic save can all land on the same second.
    @Test func repeatedIdenticalPositionsDoNotRewrite() throws {
        let store = makeStore()
        let a = try #require(open(fileA, in: store))
        store.setPosition(10, for: a.id)

        let written = defaults.suite.data(forKey: Self.documentsKey)
        defaults.suite.removeObject(forKey: Self.documentsKey)
        store.setPosition(10, for: a.id)

        #expect(written != nil)
        #expect(defaults.suite.data(forKey: Self.documentsKey) == nil)
    }

    // MARK: - Removal

    /// Positions can no longer be orphaned: they leave with the record that owns them.
    @Test func removingADocumentTakesItsPosition() throws {
        let store = makeStore()
        let a = try #require(open(fileA, in: store))
        store.setPosition(3843.5, for: a.id)

        store.remove(a.id)

        #expect(store.documents.isEmpty)
        #expect(makeStore().documents.isEmpty)
    }

    @Test func clearEmptiesAndPersists() {
        let store = makeStore()
        open(fileA, in: store)
        open(fileB, in: store)

        store.clear()

        #expect(store.documents.isEmpty)
        #expect(makeStore().documents.isEmpty)
        #expect(systemRecents.clearCount == 1)
    }

    // MARK: - System mirroring

    /// The system list has to be told the URL the bookmark resolved to, not the one the caller
    /// asked for, or its entry reopens something else.
    @Test func confirmingMirrorsTheResolvedURL() throws {
        let store = makeStore()
        let first = try #require(open(fileA, in: store))

        bookmarks.redirect(first.bookmarkData, to: fileB)
        reopen(first.id, in: store)

        #expect(systemRecents.noted == [fileA, fileB])
    }

    @Test func trimDropsTheOldestPastTheCap() {
        let store = makeStore(maximumCount: 3)

        for index in 0...3 {
            open(URL(filePath: "/tmp/file-\(index).mp4"), in: store)
        }

        #expect(store.documents.count == 3)
        #expect(!store.documents.contains { $0.url.lastPathComponent == "file-0.mp4" })
    }

    /// Recent Items can be set to None, which must drop everything rather than trap on the trim.
    @Test func aZeroCapKeepsNothing() {
        let store = makeStore(maximumCount: 0)

        open(fileA, in: store)

        #expect(store.documents.isEmpty)
    }

    // MARK: - Loading

    /// Bookmarks are resolved lazily, so an unreachable file - deleted, or on an unmounted volume -
    /// stays in the list until the user actually tries to open it.
    @Test func unresolvableDocumentsAreKeptOnLoad() throws {
        let store = makeStore()
        let a = try #require(open(fileA, in: store))
        store.setPosition(500, for: a.id)

        bookmarks.unresolvable = [a.bookmarkData]

        let reloaded = makeStore()
        #expect(reloaded.documents.count == 1)
        #expect(reloaded.documents.first?.position == 500)
    }

    @Test func corruptStoredDataYieldsAnEmptyList() {
        defaults.suite.set(Data([0xDE, 0xAD, 0xBE, 0xEF]), forKey: Self.documentsKey)

        #expect(makeStore().documents.isEmpty)
    }

    @Test func legacyKeysAreRemovedOnLoad() {
        defaults.suite.set([Data([0x01])], forKey: "RecentDocumentBookmarks")
        defaults.suite.set(["file:///tmp/a.mp4": 12.0], forKey: "PlaybackPositions")

        _ = makeStore()

        #expect(defaults.suite.object(forKey: "RecentDocumentBookmarks") == nil)
        #expect(defaults.suite.object(forKey: "PlaybackPositions") == nil)
    }
}
