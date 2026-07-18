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

    private var positions: [String: TimeInterval]

    private init() {
        let raw = UserDefaults.standard.dictionary(forKey: Self.defaultsKey) ?? [:]
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

    private func persist() {
        UserDefaults.standard.set(positions, forKey: Self.defaultsKey)
    }
}
