//
//  RecentDocumentAlerts.swift
//  Front Row
//
//  Created by Joshua Park on 8/1/26.
//

import SwiftUI

/// The alerts shown when a file couldn't be opened.
///
/// Attached to both the player and welcome scenes, since either can be frontmost when an open
/// fails - File > Open Recent is reachable from both.
private struct RecentDocumentAlerts: ViewModifier {
    @Environment(PresentedViewManager.self) private var presentedViewManager: PresentedViewManager

    func body(content: Content) -> some View {
        @Bindable var presentedViewManager = presentedViewManager

        content
            .alert(
                Text(
                    "\"\(presentedViewManager.unavailableRecentDocument?.lastPathComponent ?? "")\" isn't available",
                    comment: "Alert title shown when a recent file can't be reached"
                ),
                isPresented: $presentedViewManager.isPresentingUnavailableRecentDocumentAlert,
                presenting: presentedViewManager.unavailableRecentDocument
            ) { url in
                Button(role: .destructive) {
                    RecentDocumentsStore.shared.removeRecentDocument(url)
                } label: {
                    Text("Remove", comment: "Removes an unavailable file from recent files")
                }

                Button(role: .cancel) {
                } label: {
                    Text("Cancel", comment: "Keeps an unavailable file in recent files")
                }
            } message: { _ in
                Text(
                    "Do you want to remove it from your recent files?",
                    comment: "Alert message shown when a recent file can't be reached"
                )
            }
            .alert(
                Text("Couldn't Open File", comment: "Alert title shown when a file won't play"),
                isPresented: $presentedViewManager.isPresentingUnplayableFileAlert
            ) {
                Button("OK") {}
            } message: {
                Text(
                    "\"\(presentedViewManager.unplayableFileName ?? "")\" could not be opened.",
                    comment: "Alert message shown when a file won't play"
                )
            }
    }
}

extension View {
    /// Presents the alerts for files that couldn't be opened. Apply once per window scene.
    func recentDocumentAlerts() -> some View {
        modifier(RecentDocumentAlerts())
    }
}
