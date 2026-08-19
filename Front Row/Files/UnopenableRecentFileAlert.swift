//
//  UnopenableRecentFileAlert.swift
//  Front Row
//
//  Created by Joshua Park on 8/2/26.
//

import SwiftUI

/// A recent file that couldn't be opened, and everything needed to explain why.
struct UnopenableRecentFile {
    var url: URL
    var result: FileOpenResult
    /// The disconnected volume the file lives on, if that's why it wouldn't open.
    var unavailableVolumeName: String?
    /// The scene that raised this, and so the only one that presents it.
    var scene: AlertScene
}

/// What the "couldn't open a recent file" alert should say and do.
///
/// Kept apart from the view so the mapping - which buttons appear, and which of them drops the
/// entry - can be tested without AVFoundation or a window.
enum UnopenableRecentFileAlert: Equatable {

    /// The file's volume isn't mounted, so the file itself is probably fine.
    case volumeOffline(volumeName: String?)

    /// The volume is mounted but the file couldn't be read: moved off the volume, or deleted.
    case unreadable

    /// The file is right there but isn't a format that can be played.
    case unplayable

    enum Button: Equatable {
        case ok
        case removeFromRecents
    }

    init(file: UnopenableRecentFile) {
        switch file.result {
        case .unplayable:
            self = .unplayable
        case .unreadable, .opened, .handedToConverter:
            if let volumeName = file.unavailableVolumeName {
                self = .volumeOffline(volumeName: volumeName)
            } else {
                self = .unreadable
            }
        }
    }

    /// Every case leads with OK. Whether that also drops the entry is `removesEntry(_:)`'s call.
    var defaultButton: Button { .ok }

    /// Only the offline drive needs a second button, since it's the one case where OK leaves the
    /// entry behind and the user might still want it gone.
    var secondaryButton: Button? {
        switch self {
        case .volumeOffline: .removeFromRecents
        case .unreadable, .unplayable: nil
        }
    }

    /// Whether dismissing with `button` should drop the entry from recents.
    func removesEntry(_ button: Button) -> Bool {
        switch button {
        case .removeFromRecents:
            true
        case .ok:
            switch self {
            // The drive is coming back, so the entry and the playback position inside it have to
            // survive being dismissed. This is the case the offline check exists to catch.
            case .volumeOffline: false
            // Whatever's recoverable was already caught as `.volumeOffline`: the volume is right
            // there and the file still wouldn't open, so it's taken as gone. An unplayable file
            // shouldn't have been listed at all, since entries are only added after a successful
            // open. Either way the single OK cleans up rather than just dismissing.
            case .unreadable, .unplayable: true
            }
        }
    }
}

extension View {
    /// Presents the "couldn't open a recent file" alert when it was raised in `scene`. Apply once
    /// per window scene.
    func unopenableRecentFileAlert(in scene: AlertScene) -> some View {
        modifier(UnopenableRecentFileAlertModifier(scene: scene))
    }
}

private struct UnopenableRecentFileAlertModifier: ViewModifier {
    let scene: AlertScene

    @Environment(PresentationModel.self) private var presentationModel: PresentationModel

    /// True only for the scene the failure was raised in, so the other stays quiet rather than
    /// presenting a duplicate - and only that scene may take it down again. Both scenes hold one of
    /// these, and a `false` from the one that is not presenting would otherwise clear the alert the
    /// other is still showing.
    private var isPresented: Binding<Bool> {
        Binding(
            get: { presentationModel.unopenableRecentFile?.scene == scene },
            set: { isPresented in
                if !isPresented { presentationModel.dismissUnopenableRecentFile(in: scene) }
            }
        )
    }

    func body(content: Content) -> some View {
        content.alert(
            Text(
                "Couldn't Open File",
                comment: "Title of the alert shown when a recent file could not be opened"
            ),
            isPresented: isPresented,
            presenting: presentationModel.unopenableRecentFile
        ) { file in
            let alert = UnopenableRecentFileAlert(file: file)
            AlertButton(alert.defaultButton, alert: alert, file: file)
            if let secondaryButton = alert.secondaryButton {
                AlertButton(secondaryButton, alert: alert, file: file)
            }
        } message: { file in
            AlertMessage(alert: UnopenableRecentFileAlert(file: file), file: file)
        }
        .onDisappear { presentationModel.dismissUnopenableRecentFile(in: scene) }
    }
}

private struct AlertButton: View {
    let button: UnopenableRecentFileAlert.Button
    let alert: UnopenableRecentFileAlert
    let file: UnopenableRecentFile

    init(
        _ button: UnopenableRecentFileAlert.Button, alert: UnopenableRecentFileAlert,
        file: UnopenableRecentFile
    ) {
        self.button = button
        self.alert = alert
        self.file = file
    }

    var body: some View {
        switch button {
        case .ok:
            Button(action: act) {
                Text(
                    "OK",
                    comment: "Dismisses the alert shown when a recent file couldn't be opened"
                )
            }
        case .removeFromRecents:
            Button(action: act) {
                Text(
                    "Remove from Recents",
                    comment: "Alert button that drops a file from the recent files list"
                )
            }
        }
    }

    private func act() {
        guard alert.removesEntry(button) else { return }
        RecentDocumentsStore.shared.removeRecentDocument(file.url)
    }
}

private struct AlertMessage: View {
    let alert: UnopenableRecentFileAlert
    let file: UnopenableRecentFile

    var body: some View {
        let name = file.url.lastPathComponent

        switch alert {
        case .volumeOffline(let volumeName):
            Text(
                "\"\(name)\" is on \"\(volumeName ?? "")\", which isn't connected. Connect it and try again.",
                comment:
                    "Alert message shown when a recent file's drive or network share is not mounted"
            )
        case .unreadable:
            Text(
                "\"\(name)\" couldn't be opened. It may have been moved or deleted.",
                comment: "Alert message shown when a recent file can no longer be found"
            )
        case .unplayable:
            Text(UnplayableFileMessage.text(for: file.url))
        }
    }
}
