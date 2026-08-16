//
//  URL+RecentDocumentIcon.swift
//  Front Row
//
//  Created by Joshua Park on 7/17/26.
//

import AppKit
import UniformTypeIdentifiers

extension URL {
    /// An icon suitable for representing this URL in the Open Recent menu / welcome screen,
    /// whether it points to a local file or a remote resource.
    var recentDocumentIcon: NSImage {
        if isFileURL {
            return NSWorkspace.shared.icon(forFile: path(percentEncoded: false))
        }
        return NSWorkspace.shared.icon(for: .url)
    }
}
