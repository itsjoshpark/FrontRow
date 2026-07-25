//
//  DocumentControllerRecents.swift
//  Front Row
//
//  Created by Joshua Park on 7/19/26.
//

import AppKit

/// The real `SystemRecentsMirroring`, backed by `NSDocumentController`.
///
/// `maximumCount` is read through rather than captured, since the user can change the preference
/// while the app is running.
@MainActor
struct DocumentControllerRecents: SystemRecentsMirroring {

    var maximumCount: Int {
        NSDocumentController.shared.maximumRecentDocumentCount
    }

    func note(_ url: URL) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    func clearAll() {
        NSDocumentController.shared.clearRecentDocuments(nil)
    }
}
