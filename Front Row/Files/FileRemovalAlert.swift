//
//  FileRemovalAlert.swift
//  Front Row
//
//  Created by Joshua Park on 9/26/26.
//

import SwiftUI

/// How the playing file is taken away.
enum FileRemoval: Equatable {
    case trash
    case delete
}

/// A file that couldn't be moved to the Trash or deleted, and what went wrong.
struct FileRemovalFailure {
    var url: URL
    var removal: FileRemoval
    var reason: String
}

/// What removing the playing file is asking the user. Only the player window presents it, since
/// only a file playing there can be removed.
enum FileRemovalAlert {
    case confirmDeletion(URL)
    case failure(FileRemovalFailure)
}

/// Moves the playing file to the Trash or deletes it, and drops its recents entry, which would
/// otherwise point at a file that's gone. A failure is raised as an alert instead.
///
/// Refuses a `url` that is no longer the one playing: a file opened while the confirmation was up
/// would otherwise be deleted in place of the one it named. Runs while the engine still holds the
/// file's security-scoped access.
/// - Returns: Whether the file is gone.
@MainActor
@discardableResult
func removeCurrentFile(at url: URL, _ removal: FileRemoval) -> Bool {
    let playEngine = PlayEngine.shared
    guard playEngine.isLocalFile, playEngine.fileURL == url else { return false }
    do {
        switch removal {
        case .trash: try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        case .delete: try FileManager.default.removeItem(at: url)
        }
    } catch {
        PresentationModel.shared.raise(
            .failure(
                FileRemovalFailure(
                    url: url, removal: removal, reason: error.localizedDescription)))
        return false
    }
    RecentDocumentsStore.shared.removeRecentDocument(url)
    return true
}

extension View {
    /// Presents the file removal alert. Applied to the player window only.
    ///
    /// Once the file is gone, the welcome window is opened before the player closes, since closing
    /// the last window quits the app.
    func fileRemovalAlert() -> some View {
        modifier(FileRemovalAlertModifier())
    }
}

private struct FileRemovalAlertModifier: ViewModifier {
    @Environment(PresentationModel.self) private var presentationModel: PresentationModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    private var isPresented: Binding<Bool> {
        Binding(
            get: { presentationModel.fileRemovalAlert != nil },
            set: { isPresented in
                if !isPresented { presentationModel.dismissFileRemovalAlert() }
            }
        )
    }

    func body(content: Content) -> some View {
        content.alert(
            FileRemovalAlertTitle.text(for: presentationModel.fileRemovalAlert),
            isPresented: isPresented,
            presenting: presentationModel.fileRemovalAlert
        ) { alert in
            switch alert {
            case .confirmDeletion(let url):
                Button(role: .destructive) {
                    // After the confirmation has gone: a failure raised from here would find
                    // the slot still taken.
                    Task {
                        guard removeCurrentFile(at: url, .delete) else { return }
                        openWindow(id: WindowID.welcome)
                        dismissWindow(id: WindowID.main)
                    }
                } label: {
                    Text("Delete", comment: "Alert button that confirms Delete Immediately")
                }
                Button(role: .cancel) {
                } label: {
                    Text("Cancel", comment: "Alert button that cancels Delete Immediately")
                }
            case .failure:
                Button {
                } label: {
                    Text(
                        "OK",
                        comment: "Dismisses the alert shown when a file couldn’t be removed"
                    )
                }
            }
        } message: { alert in
            switch alert {
            case .confirmDeletion:
                Text(
                    "This item will be deleted immediately. You can’t undo this action.",
                    comment: "Message of the alert confirming Delete Immediately"
                )
            case .failure(let failure):
                Text(failure.reason)
            }
        }
        .onDisappear { presentationModel.dismissFileRemovalAlert() }
    }
}

/// An alert title has to be a `Text`, so this is a function rather than a view.
private enum FileRemovalAlertTitle {
    static func text(for alert: FileRemovalAlert?) -> Text {
        switch alert {
        case .confirmDeletion(let url):
            Text(
                "Are you sure you want to delete “\(url.lastPathComponent)”?",
                comment:
                    "Title of the alert confirming Delete Immediately; the argument is a file name"
            )
        case .failure(let failure) where failure.removal == .trash:
            Text(
                "Couldn’t Move “\(failure.url.lastPathComponent)” to the Trash",
                comment: "Title of the alert shown when a file couldn’t be moved to the Trash"
            )
        case .failure(let failure):
            Text(
                "Couldn’t Delete “\(failure.url.lastPathComponent)”",
                comment: "Title of the alert shown when a file couldn’t be deleted"
            )
        case nil:
            Text(verbatim: "")
        }
    }
}
