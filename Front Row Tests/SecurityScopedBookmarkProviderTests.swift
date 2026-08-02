//
//  SecurityScopedBookmarkProviderTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

struct SecurityScopedBookmarkProviderTests {

    /// The recent documents list is built by reading each entry's path out of its bookmark instead
    /// of resolving it, so that a file on a detached volume stays listed. This pins the Foundation
    /// behavior that rests on: a bookmark still yields its path once resolution has stopped
    /// working. A deleted file stands in for an unmounted one - both fail resolution identically.
    @Test
    func pathIsReadableFromBookmarkDataAfterTheFileIsGone() throws {
        let provider = SecurityScopedBookmarkProvider()

        let file = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")
        try Data("front row".utf8).write(to: file)

        let bookmarkData = try #require(provider.bookmarkData(for: file))

        // Compares the bookmark's own reading before and after, rather than against the URL it was
        // made from: a bookmark records the canonical path, and canonicalization doesn't survive
        // the file being deleted, which would make a direct comparison test the wrong thing.
        let pathWhileFileExists = try #require(provider.url(fromBookmarkData: bookmarkData)?.path())
        #expect(pathWhileFileExists.hasSuffix(file.lastPathComponent))

        try FileManager.default.removeItem(at: file)

        #expect(provider.resolveBookmark(bookmarkData) == nil)
        #expect(provider.url(fromBookmarkData: bookmarkData)?.path() == pathWhileFileExists)
    }
}
