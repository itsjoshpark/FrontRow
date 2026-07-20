//
//  ScopedAccess.swift
//  Front Row
//
//  Created by Joshua Park on 7/19/26.
//

import Foundation

/// Owns a single security-scoped grant, releasing it when the last reference goes away.
///
/// Tying the grant to an object's lifetime rather than to a manual stop call means a file that
/// fails to open releases its grant automatically, and the previously playing file's grant is held
/// until its replacement is known to be good.
final class ScopedAccess {

    let url: URL

    private let onRelease: @Sendable (URL) -> Void

    init(url: URL, onRelease: @escaping @Sendable (URL) -> Void) {
        self.url = url
        self.onRelease = onRelease
    }

    deinit {
        onRelease(url)
    }
}
