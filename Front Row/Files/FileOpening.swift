//
//  FileOpening.swift
//  Front Row
//
//  Created by Joshua Park on 7/17/26.
//

import SwiftUI

/// Presents the Open File panel and returns the user's chosen URL, or `nil` if they canceled.
@MainActor
func presentOpenFilePanel() async -> URL? {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = PlayEngine.openableFileTypes
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.canChooseFiles = true

    // Sheeted onto the main window where there is one. Opening a file is also how the app is
    // started, and at that point there may be no window to hang a sheet from.
    let response: NSApplication.ModalResponse
    if let window = NSApplication.shared.mainWindow {
        response = await panel.beginSheetModal(for: window)
    } else {
        response = await panel.begin()
    }

    guard response == .OK else { return nil }
    return panel.url
}

/// Presents the Open File panel and opens whatever the user picks.
@MainActor
func showOpenFileDialog() async {
    guard let url = await presentOpenFilePanel() else { return }
    await openFile(url: url)
}

/// Opens a file, records it in recent documents, and brings the main player window forward.
///
/// This is the single entry point every file-opening path should use so recent-document tracking
/// and the welcome-to-player transition stay consistent - and so a failure is diagnosed the same
/// way wherever it was asked for.
@MainActor
@discardableResult
func openFile(
    url: URL, reachability: any NetworkReachabilityProviding = NetworkReachability.shared
) async -> FileOpenResult {
    // Handled before AVFoundation is asked, which would only fail: Matroska has to become an MP4
    // before there is anything to play or to note in recents.
    if PlayEngine.isConvertible(url) {
        await MediaConversion.offerConversion(of: url)
        return .handedToConverter
    }

    let result = await PlayEngine.shared.loadAndPlay(url: url)
    guard result == .opened else {
        return await diagnosingOffline(result, url: url, reachability: reachability)
    }

    // What actually opened, not what was asked for: a bookmark tracks file identity, so a file
    // renamed outside the app opens from its new location. Noting the stale URL would match no
    // entry and quietly leave the file out of recents.
    RecentDocumentsStore.shared.noteRecentDocument(PlayEngine.shared.fileURL ?? url)
    WelcomeWindowCoordinator.shared.presentMainWindow()
    return .opened
}

/// Re-reads a failed open as `.offline` where nothing could have been reached anyway.
///
/// Only a remote file can be blamed on the connection: a local one is sitting on a disk that is
/// there whether or not the machine is. The network is consulted second so that ordinary local
/// failures never start a monitor at all.
func diagnosingOffline(
    _ result: FileOpenResult, url: URL, reachability: any NetworkReachabilityProviding
) async -> FileOpenResult {
    guard result == .unreadable, !url.isFileURL else { return result }
    return await reachability.isConnected() ? result : .offline
}

/// Opens a file that's already in recent documents. On failure, explains why - and only a
/// disconnected drive or a missing network connection keeps its entry, since both are coming back.
/// Where the file was reachable and still wouldn't open, dismissing the alert clears it.
@MainActor
func openRecentDocument(url: URL) async {
    let result = await openFile(url: url)
    // The converter explains itself, so a second alert here would only talk over it.
    guard result != .opened, result != .handedToConverter else { return }

    PresentationModel.shared.raise(
        UnopenableRecentFile(
            url: url,
            result: result,
            unavailableVolumeName: RecentDocumentsStore.shared.unavailableVolumeName(for: url),
            scene: .current
        )
    )
}
