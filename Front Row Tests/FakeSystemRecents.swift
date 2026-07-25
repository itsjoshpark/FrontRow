//
//  FakeSystemRecents.swift
//  Front Row Tests
//
//  Created by Joshua Park on 7/19/26.
//

import Foundation

@testable import Front_Row

/// A `SystemRecentsMirroring` that records what it was told instead of touching the user's real
/// recent documents, and whose cap can be set to values the machine's preference may not be at.
@MainActor
final class FakeSystemRecents: SystemRecentsMirroring {

    var maximumCount: Int

    private(set) var noted: [URL] = []

    private(set) var clearCount = 0

    init(maximumCount: Int = 10) {
        self.maximumCount = maximumCount
    }

    func note(_ url: URL) {
        noted.append(url)
    }

    func clearAll() {
        clearCount += 1
    }
}
