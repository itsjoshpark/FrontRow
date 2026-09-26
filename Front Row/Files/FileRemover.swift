//
//  FileRemover.swift
//  Front Row
//
//  Created by Joshua Park on 9/26/26.
//

import SwiftUI

/// How the playing file is taken away.
enum FileRemoval {
    case trash
    case delete
}

/// Moves the playing file to the Trash or deletes it, on the user's say-so.
@MainActor
struct FileRemover {
    /// The local file the player is showing, if any.
    var playingFile: () -> URL?
    var recentDocuments: RecentDocumentsStore
    var presentationModel: PresentationModel

    init(
        playingFile: @escaping () -> URL? = {
            PlayEngine.shared.isLocalFile ? PlayEngine.shared.fileURL : nil
        },
        recentDocuments: RecentDocumentsStore = .shared,
        presentationModel: PresentationModel = .shared
    ) {
        self.playingFile = playingFile
        self.recentDocuments = recentDocuments
        self.presentationModel = presentationModel
    }

    /// Removes `url` and drops its recents entry, which would otherwise point at a file that's
    /// gone. A failure is raised as an alert instead.
    ///
    /// Refuses a `url` that is no longer the one playing: a file opened while the confirmation was
    /// up would otherwise be deleted in place of the one it named. Runs while the engine still
    /// holds the file's security-scoped access.
    /// - Returns: Whether the file is gone.
    @discardableResult
    func remove(_ url: URL, _ removal: FileRemoval) -> Bool {
        guard playingFile() == url else { return false }
        do {
            switch removal {
            case .trash: try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            case .delete: try FileManager.default.removeItem(at: url)
            }
        } catch {
            presentationModel.raise(
                .failure(
                    FileRemovalFailure(
                        url: url, removal: removal, reason: error.localizedDescription)))
            return false
        }
        recentDocuments.removeRecentDocument(url)
        return true
    }

    /// Removes `url` and, once it's gone, puts the welcome window in the player's place. The
    /// welcome window opens first, since closing the last window quits the app.
    func remove(
        _ url: URL, _ removal: FileRemoval, openWindow: OpenWindowAction,
        dismissWindow: DismissWindowAction
    ) {
        guard remove(url, removal) else { return }
        openWindow(id: WindowID.welcome)
        dismissWindow(id: WindowID.main)
    }
}
