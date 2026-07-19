//
//  BookmarkCanaryTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

@MainActor
struct BookmarkCanaryTests {

    @Test func realSecurityScopedBookmarkRoundTrips() throws {
        let file = URL.temporaryDirectory.appending(path: "canary-\(UUID().uuidString).mp4")
        try Data([0x00]).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let data = try file.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil, relativeTo: nil)

        var isStale = false
        let resolved = try URL(
            resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil,
            bookmarkDataIsStale: &isStale)

        #expect(resolved.lastPathComponent == file.lastPathComponent)
        #expect(resolved.startAccessingSecurityScopedResource())
        resolved.stopAccessingSecurityScopedResource()
    }
}
