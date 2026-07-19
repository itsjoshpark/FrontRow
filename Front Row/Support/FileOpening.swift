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

/// Opens a local file, records it in recent documents, and brings the main player window forward.
///
/// This is the single entry point every local-file path should use so recent-document tracking and
/// the welcome-to-player transition stay consistent. The file is only committed to recents once
/// playback has started, so an unplayable file leaves no trace.
@MainActor
@discardableResult
func openFileAndPresent(url: URL) async -> Bool {
    guard let prepared = RecentDocumentsStore.shared.prepareToOpen(url) else { return false }

    guard await PlayEngine.shared.open(prepared) else {
        RecentDocumentsStore.shared.remove(prepared.id)
        return false
    }

    RecentDocumentsStore.shared.confirmOpened(prepared)
    WelcomeWindowCoordinator.shared.presentMainWindow()
    return true
}

/// Opens a remote resource and brings the main player window forward. Remote URLs can't be
/// bookmarked, so they're never added to recent documents.
@MainActor
@discardableResult
func openRemoteAndPresent(url: URL) async -> Bool {
    guard await PlayEngine.shared.openRemote(url: url) else { return false }
    WelcomeWindowCoordinator.shared.presentMainWindow()
    return true
}

/// Opens a file that's already in recent documents. On failure, shows an alert and removes the
/// broken entry from history.
@MainActor
func openRecentDocumentAndPresent(id: RecentDocument.ID) async {
    guard let document = RecentDocumentsStore.shared.documents.first(where: { $0.id == id })
    else { return }

    guard !(await openFileAndPresent(url: document.url)) else { return }

    RecentDocumentsStore.shared.remove(id)
    PresentedViewManager.shared.brokenRecentFileName = document.url.lastPathComponent
}
