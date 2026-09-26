//
//  FileRemovalAlert.swift
//  Front Row
//
//  Created by Joshua Park on 9/26/26.
//

import SwiftUI

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

extension View {
    /// Presents the file removal alert. Applied to the player window only.
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
                        FileRemover().remove(
                            url, .delete, openWindow: openWindow, dismissWindow: dismissWindow)
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
