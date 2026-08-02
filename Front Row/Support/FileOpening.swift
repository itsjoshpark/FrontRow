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

/// The outcome of trying to open a media file.
///
/// AVFoundation distinguishes "couldn't read this" from "read it, can't decode it", and the two
/// call for different UI: the first may mean the file is gone or its drive is unplugged, the
/// second means it's sitting right there in an unsupported format.
enum FileOpenResult {
    case opened
    /// The file couldn't be read at all - deleted, or on a disconnected volume.
    case unreadable
    /// The file was read, but it isn't a format that can be played.
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
func openFileAndPresent(url: URL) async -> FileOpenResult {
    let result = await PlayEngine.shared.openFile(url: url)
    guard result == .opened else { return result }

    // What actually opened, not what was asked for: a bookmark tracks file identity, so a file
    // renamed outside the app opens from its new location. Noting the stale URL would match no
    // entry and quietly leave the file out of recents.
    RecentDocumentsStore.shared.noteRecentDocument(PlayEngine.shared.fileURL ?? url)
    WelcomeWindowCoordinator.shared.presentMainWindow()
    return .opened
}

/// Opens a file that's already in recent documents. On failure, explains why - and only a
/// disconnected drive keeps its entry, since that one is coming back. Where the volume is present
/// and the file still wouldn't open, dismissing the alert clears it.
@MainActor
func openRecentDocumentAndPresent(url: URL) async {
    let result = await openFileAndPresent(url: url)
    guard result != .opened else { return }

    PresentedViewManager.shared.unopenableRecentFile = UnopenableRecentFile(
        url: url,
        result: result,
        unavailableVolumeName: RecentDocumentsStore.shared.unavailableVolumeName(for: url)
    )
}
