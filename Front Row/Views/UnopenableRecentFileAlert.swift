//
//  UnopenableRecentFileAlert.swift
//  Front Row
//
//  Created by Joshua Park on 8/2/26.
//

import SwiftUI

/// What the "couldn't open a recent file" alert should say and do.
///
/// Kept apart from the view so the mapping - which button is the default, and which of them drops
/// the entry - can be tested without AVFoundation or a window.
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
        case .unreadable, .opened:
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
    /// Presents the "couldn't open a recent file" alert, but only when this view's window is the
    /// key one.
    ///
    /// The alert state is app-wide, and the welcome and player windows can both be open at once
    /// (the welcome window is reachable from the Window menu while a file plays). Without the
    /// gate, both would raise their own copy of the same alert.
    func unopenableRecentFileAlert() -> some View {
        modifier(UnopenableRecentFileAlertModifier())
    }
}

private struct UnopenableRecentFileAlertModifier: ViewModifier {
    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(PresentedViewManager.self) private var presentedViewManager: PresentedViewManager

    /// Falls to `false` when the window stops being key, which dismisses the alert without
    /// clearing the underlying state - so it comes back when the user returns to this window.
    ///
    /// The setter only clears while this window is still key, since SwiftUI may write the
    /// getter's own `false` back on a focus change; a real dismissal comes from a button, which
    /// clears the state itself.
    private var isPresented: Binding<Bool> {
        Binding(
            get: {
                presentedViewManager.unopenableRecentFile != nil && controlActiveState == .key
            },
            set: { isPresented in
                if !isPresented, controlActiveState == .key {
                    presentedViewManager.unopenableRecentFile = nil
                }
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
            presenting: presentedViewManager.unopenableRecentFile
        ) { file in
            let alert = UnopenableRecentFileAlert(file: file)
            AlertButton(alert.defaultButton, alert: alert, file: file)
            if let secondaryButton = alert.secondaryButton {
                AlertButton(secondaryButton, alert: alert, file: file)
            }
        } message: { file in
            AlertMessage(alert: UnopenableRecentFileAlert(file: file), file: file)
        }
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
            Button(role: .destructive, action: act) {
                Text(
                    "Remove from Recents",
                    comment: "Alert button that drops a file from the recent files list"
                )
            }
        }
    }

    /// Clears the alert state itself rather than leaving that to the `isPresented` binding, whose
    /// value also tracks window focus - so dismissal can't be confused with the window merely
    /// losing key.
    private func act() {
        if alert.removesEntry(button) {
            RecentDocumentsStore.shared.removeRecentDocument(file.url)
        }
        PresentedViewManager.shared.unopenableRecentFile = nil
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
            Text(
                "\"\(name)\" isn't a format Front Row can play.",
                comment: "Alert message shown when a recent file exists but cannot be decoded"
            )
        }
    }
}
