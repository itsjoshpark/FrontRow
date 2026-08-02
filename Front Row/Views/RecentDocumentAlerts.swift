//
//  RecentDocumentAlerts.swift
//  Front Row
//
//  Created by Joshua Park on 8/1/26.
//

import SwiftUI

/// The alert shown when a recent document couldn't be opened.
///
/// Applied to both the player and welcome scenes, since File > Open Recent is reachable from
/// either. Only the scene the failure was raised in presents: both can be alive at once, and a
/// dismissed one would otherwise show a second copy and resurface its own window doing so.
private struct RecentDocumentAlerts: ViewModifier {
    let scene: AlertScene

    @Environment(PresentedViewManager.self) private var presentedViewManager: PresentedViewManager

    /// True only for the scene the alert was raised in, so the other scene stays quiet instead of
    /// presenting a duplicate.
    private var isPresented: Binding<Bool> {
        Binding(
            get: { presentedViewManager.unopenableRecentDocument?.scene == scene },
            set: { isPresented in
                if !isPresented {
                    presentedViewManager.unopenableRecentDocument = nil
                }
            }
        )
    }

    func body(content: Content) -> some View {
        content
            .alert(
                presentedViewManager.unopenableRecentDocument?.alertTitle ?? Text(verbatim: ""),
                isPresented: isPresented,
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
    /// Presents the alert for a recent document that couldn't be opened, when it was raised in
    /// `scene`. Apply once per window scene.
    func recentDocumentAlerts(in scene: AlertScene) -> some View {
        modifier(RecentDocumentAlerts(scene: scene))
    }
}
