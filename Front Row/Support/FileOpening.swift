//
//  FileOpening.swift
//  Front Row
//
//  Created by Joshua Park on 7/17/26.
//

import SwiftUI

/// Identifiers for the app's `Window` scenes.
enum WindowID {
    static let main = "main"
    static let welcome = "welcome"
}

/// Why opening a file did or didn't work.
///
/// The two failures are distinguished to word the prompt accurately, not to decide whether to
/// prompt - either way the user is asked whether to forget the entry.
///
/// Reaching a file resolves its bookmark, which can land somewhere other than the URL passed in if
/// the file has moved, so the cases that got that far carry the URL actually used. Callers that
/// identify the file afterwards must use that one: the store re-keys a moved entry to it, and the
/// URL passed in no longer matches.
enum OpenFileOutcome: Equatable {
    case opened(url: URL)

    /// The file couldn't be reached - e.g. its volume isn't mounted, or it was deleted. Never
    /// re-keys the entry, so the URL passed in is still its identity.
    case unavailable

    /// The file was reached but holds no playable content.
    case unplayable(url: URL)
}

/// Presents the Open File panel and returns the user's chosen URL, or `nil` if they canceled.
@MainActor
func presentOpenFilePanel() async -> URL? {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = PlayEngine.supportedFileTypes
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    let response = await panel.beginSheetModal(for: NSApplication.shared.mainWindow!)
    guard response == .OK else { return nil }
    return panel.url
}

/// Opens a file, records it in recent documents, and brings the main player window forward.
///
/// This is the single entry point every file-opening path should use so recent-document tracking
/// and the welcome-to-player transition stay consistent.
@MainActor
@discardableResult
func openFileAndPresent(url: URL) async -> OpenFileOutcome {
    let outcome = await PlayEngine.shared.openFile(url: url)
    guard case .opened(let openedURL) = outcome else { return outcome }
    RecentDocumentsStore.shared.noteRecentDocument(openedURL)
    WelcomeWindowCoordinator.shared.presentMainWindow()
    return outcome
}

/// Opens a file that's already in recent documents, asking whether to forget it if it won't open.
///
/// A failed entry is never removed here - neither failure is reliably permanent - so the alert
/// asks, and leaves the entry and its saved position alone unless the user says otherwise.
@MainActor
func openRecentDocumentAndPresent(url: URL) async {
    let unopenable: UnopenableRecentDocument
    switch await openFileAndPresent(url: url) {
    case .opened:
        return
    case .unavailable:
        unopenable = .init(url: url, reason: .unavailable, scene: .current)
    case .unplayable(let openedURL):
        unopenable = .init(url: openedURL, reason: .unplayable, scene: .current)
    }

    PresentedViewManager.shared.unopenableRecentDocument = unopenable
}
