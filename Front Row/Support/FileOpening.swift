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

/// Opens a file, records it in recent documents, and brings the main player window forward.
///
/// This is the single entry point every file-opening path should use so recent-document tracking
/// and the welcome-to-player transition stay consistent.
@MainActor
@discardableResult
func openFileAndPresent(url: URL) async -> Bool {
    guard await PlayEngine.shared.openFile(url: url) else { return false }
    RecentDocumentsStore.shared.noteRecentDocument(url)
    WelcomeWindowCoordinator.shared.presentMainWindow()
    return true
}

/// Opens a file that's already in recent documents. On failure, shows an alert and removes the
/// broken entry from history.
@MainActor
func openRecentDocumentAndPresent(url: URL) async {
    guard !(await openFileAndPresent(url: url)) else { return }

    RecentDocumentsStore.shared.removeRecentDocument(url)
    PresentedViewManager.shared.brokenRecentFileName = url.lastPathComponent
}
