//
//  PlaybackPositionStoreTests.swift
//  Front RowTests
//
//  Created by Joshua Park on 7/19/26.
//

import Foundation
import Testing

@testable import Front_Row

@MainActor
struct PlaybackPositionStoreTests {

    private let fileA = URL(filePath: "/tmp/a.mp4")
    private let fileB = URL(filePath: "/tmp/b.mp4")

    @Test func roundTripsAPosition() {
        let defaults = TestDefaults()
        let store = PlaybackPositionStore(defaults: defaults.suite)

        store.setPosition(123.5, for: fileA)

        #expect(store.position(for: fileA) == 123.5)
        #expect(store.position(for: fileB) == nil)
    }

    @Test func clearingRemovesOnlyTheGivenFile() {
        let defaults = TestDefaults()
        let store = PlaybackPositionStore(defaults: defaults.suite)
        store.setPosition(10, for: fileA)
        store.setPosition(20, for: fileB)

        store.clearPosition(for: fileA)

        #expect(store.position(for: fileA) == nil)
        #expect(store.position(for: fileB) == 20)
    }

    @Test func positionsSurviveReload() {
        let defaults = TestDefaults()
        PlaybackPositionStore(defaults: defaults.suite).setPosition(42, for: fileA)

        #expect(PlaybackPositionStore(defaults: defaults.suite).position(for: fileA) == 42)
    }

    @Test func retainOnlyDropsUnlistedFiles() {
        let defaults = TestDefaults()
        let store = PlaybackPositionStore(defaults: defaults.suite)
        store.setPosition(10, for: fileA)
        store.setPosition(20, for: fileB)

        store.retainOnly(urls: [fileB])

        #expect(store.position(for: fileA) == nil)
        #expect(store.position(for: fileB) == 20)
        // The drop must reach disk, not just the in-memory cache.
        #expect(PlaybackPositionStore(defaults: defaults.suite).position(for: fileA) == nil)
    }

    @Test func retainOnlyKeepsEverythingWhenAllListed() {
        let defaults = TestDefaults()
        let store = PlaybackPositionStore(defaults: defaults.suite)
        store.setPosition(10, for: fileA)
        store.setPosition(20, for: fileB)

        store.retainOnly(urls: [fileA, fileB])

        #expect(store.position(for: fileA) == 10)
        #expect(store.position(for: fileB) == 20)
    }

    @Test func retainOnlyWithNoMatchesClearsEverything() {
        let defaults = TestDefaults()
        let store = PlaybackPositionStore(defaults: defaults.suite)
        store.setPosition(10, for: fileA)

        store.retainOnly(urls: [])

        #expect(store.position(for: fileA) == nil)
    }
}
