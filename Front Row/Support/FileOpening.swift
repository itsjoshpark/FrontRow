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
/// Distinguishing the two failures matters for recent documents: one warrants offering to forget
/// the file, the other doesn't.
enum OpenFileOutcome {
    case opened

    /// The file couldn't be reached - e.g. its volume isn't mounted, or it was deleted.
    case unavailable

    /// The file was reached but holds no playable content.
    case unplayable
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
    guard outcome == .opened else { return outcome }
    RecentDocumentsStore.shared.noteRecentDocument(url)
    WelcomeWindowCoordinator.shared.presentMainWindow()
    return .opened
}

/// Opens a file that's already in recent documents, asking whether to forget it if it won't open.
///
/// A failed entry is never removed here - neither failure is reliably permanent - so the alert
/// asks, and leaves the entry and its saved position alone unless the user says otherwise.
@MainActor
func openRecentDocumentAndPresent(url: URL) async {
    let reason: UnopenableRecentDocument.Reason
    switch await openFileAndPresent(url: url) {
    case .opened: return
    case .unavailable: reason = .unavailable
    case .unplayable: reason = .unplayable
    }

    PresentedViewManager.shared.unopenableRecentDocument = .init(
        url: url, reason: reason, scene: .current)
}
