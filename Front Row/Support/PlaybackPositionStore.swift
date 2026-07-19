//
//  PlaybackPositionStore.swift
//  Front Row
//
//  Created by Joshua Park on 7/18/26.
//

import Foundation

/// Persists per-file playback positions so a file can resume where it left off.
///
/// This is a pure keyed store (URL string -> seconds) with an in-memory cache backed by
/// `UserDefaults`; it deliberately knows nothing about recent documents or playback so it can be
/// depended on by both `PlayEngine` and `RecentDocumentsStore` without creating a cycle.
@MainActor
final class PlaybackPositionStore {

    static let shared = PlaybackPositionStore()

    private static let defaultsKey = "PlaybackPositions"

    private let defaults: UserDefaults

    private var positions: [String: TimeInterval]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.dictionary(forKey: Self.defaultsKey) ?? [:]
        positions = raw.compactMapValues { $0 as? TimeInterval }
    }

    func position(for url: URL) -> TimeInterval? {
        positions[url.absoluteString]
    }

    func setPosition(_ time: TimeInterval, for url: URL) {
        positions[url.absoluteString] = time
        persist()
    }

    func clearPosition(for url: URL) {
        guard positions.removeValue(forKey: url.absoluteString) != nil else { return }
        persist()
    }

    /// Drops every position not belonging to one of `urls`.
    ///
    /// Positions only exist to serve the recent documents list, so entries that outlived their
    /// recent entry - dropped because a bookmark no longer resolved, or trimmed off the end of the
    /// list - would otherwise linger indefinitely.
    func retainOnly(urls: [URL]) {
        let keep = Set(urls.map(\.absoluteString))
        let remaining = positions.filter { keep.contains($0.key) }
        guard remaining.count != positions.count else { return }

        positions = remaining
        persist()
    }

    private func persist() {
        defaults.set(positions, forKey: Self.defaultsKey)
    }
}
