//
//  RecentDocumentAlerts.swift
//  Front Row
//
//  Created by Joshua Park on 8/1/26.
//

import SwiftUI

/// The alert shown when a recent document couldn't be opened.
///
/// Attached to both the player and welcome scenes, since either can be frontmost when an open
/// fails - File > Open Recent is reachable from both.
private struct RecentDocumentAlerts: ViewModifier {
    @Environment(PresentedViewManager.self) private var presentedViewManager: PresentedViewManager

    func body(content: Content) -> some View {
        @Bindable var presentedViewManager = presentedViewManager

        content
            .alert(
                presentedViewManager.unopenableRecentDocument?.alertTitle ?? Text(verbatim: ""),
                isPresented: $presentedViewManager.isPresentingUnopenableRecentDocumentAlert,
                presenting: presentedViewManager.unopenableRecentDocument
            ) { document in
                Button(role: .destructive) {
                    RecentDocumentsStore.shared.removeRecentDocument(document.url)
                } label: {
                    Text("Remove", comment: "Removes a file that won't open from recent files")
                }

                Button(role: .cancel) {
                } label: {
                    Text("Cancel", comment: "Keeps a file that won't open in recent files")
                }
            } message: { _ in
                Text(
                    "Do you want to remove it from your recent files?",
                    comment: "Alert message shown when a recent file couldn't be opened"
                )
            }
    }
}

extension View {
    /// Presents the alert for a recent document that couldn't be opened. Apply once per window
    /// scene.
    func recentDocumentAlerts() -> some View {
        modifier(RecentDocumentAlerts())
    }
}
