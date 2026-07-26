//
//  BookmarkProviding.swift
//  Front Row
//
//  Created by Joshua Park on 7/24/26.
//

import Foundation

/// Wraps security-scoped bookmark creation/resolution so `RecentDocumentsStore` can be tested
/// without the macOS App Sandbox's real user-selected-file grants, which a test process can't
/// obtain or exercise deterministically.
protocol BookmarkProviding {
    /// Creates bookmark data for `url`. `url` must currently have active security-scoped access.
    func bookmarkData(for url: URL) -> Data?

    /// Resolves previously created bookmark data. Returns `nil` if it can no longer be resolved,
    /// e.g. because the file was deleted or permission was revoked.
    func resolveBookmark(_ data: Data) -> (url: URL, isStale: Bool)?

    /// Starts security-scoped access to a resolved URL. Returns whether access was granted.
    func startAccessingSecurityScopedResource(_ url: URL) -> Bool
}
