//
//  ScopedAccessTests.swift
//  Front Row Tests
//
//  Created by Joshua Park on 7/19/26.
//

import Foundation
import Testing

@testable import Front_Row

struct ScopedAccessTests {

    private final class ReleaseLog: @unchecked Sendable {
        private(set) var urls: [URL] = []
        func record(_ url: URL) { urls.append(url) }
    }

    private let fileA = URL(filePath: "/tmp/a.mp4")
    private let fileB = URL(filePath: "/tmp/b.mp4")

    @Test func releasesExactlyOnceWhenDiscarded() {
        let log = ReleaseLog()

        var access: ScopedAccess? = ScopedAccess(url: fileA) { log.record($0) }
        #expect(log.urls.isEmpty)

        access = nil
        _ = access

        #expect(log.urls == [fileA])
    }

    /// Two grants for different files release independently, which is what lets a new file's grant
    /// be taken before the outgoing file's is dropped.
    @Test func grantsReleaseIndependently() {
        let log = ReleaseLog()

        var outgoing: ScopedAccess? = ScopedAccess(url: fileA) { log.record($0) }
        let incoming = ScopedAccess(url: fileB) { log.record($0) }

        outgoing = nil
        _ = outgoing

        #expect(log.urls == [fileA])
        #expect(incoming.url == fileB)
    }
}
