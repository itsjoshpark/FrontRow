//
//  RemuxAlerts.swift
//  Front Row
//
//  Created by Joshua Park on 8/15/26.
//

import SwiftUI

extension View {
    /// Presents whichever conversion alert was raised in `scene`. Apply once per window scene.
    ///
    /// One modifier covering every stage rather than one per stage: a view has a single alert
    /// presentation slot, and stacked `alert` modifiers contend for it - the offer would show, and
    /// the question that follows it would silently not.
    ///
    /// The progress sheet isn't here: `ConversionProgressSheet` attaches it to the window as an
    /// `NSAlert`, not a SwiftUI presentation.
    func remuxAlert(in scene: AlertScene) -> some View {
        modifier(RemuxAlertModifier(scene: scene))
    }
}

private struct RemuxAlertModifier: ViewModifier {
    let scene: AlertScene

    @Environment(PresentedViewManager.self) private var presentedViewManager: PresentedViewManager

    private var isPresented: Binding<Bool> {
        Binding(
            get: { presentedViewManager.remuxAlert?.scene == scene },
            set: { isPresented in
                if !isPresented {
                    presentedViewManager.remuxAlert = nil
                }
            }
        )
    }

    func body(content: Content) -> some View {
        content.alert(
            RemuxAlertTitle.text(for: presentedViewManager.remuxAlert),
            isPresented: isPresented,
            presenting: presentedViewManager.remuxAlert
        ) { alert in
            RemuxAlertButtons(alert: alert)
        } message: { alert in
            RemuxAlertMessage(alert: alert)
        }
    }
}

/// An alert title has to be a `Text`, so this is a function rather than a view.
enum RemuxAlertTitle {
    static func text(for alert: RemuxAlert?) -> Text {
        switch alert {
        case .offer:
            Text(
                "Convert File?",
                comment: "Title of the alert offering to convert a Matroska file"
            )
        case .cleanup:
            Text(
                "Move Original File to Trash?",
                comment: "Title of the alert asking what to do with a converted file's original"
            )
        case .problem(let problem):
            RemuxProblemAlert.title(for: problem.reason)
        case nil:
            Text("Couldn't Open File", comment: "Alert title shown when a file can't be opened")
        }
    }
}

private struct RemuxAlertButtons: View {
    let alert: RemuxAlert

    var body: some View {
        switch alert {
        case .offer(let offer):
            Button {
                MediaConversion.startConversion(offer)
            } label: {
                Text("Convert", comment: "Alert button that starts converting a Matroska file")
            }
            Button(role: .cancel) {
            } label: {
                Text("Cancel", comment: "Alert button that declines converting a Matroska file")
            }
        case .cleanup(let cleanup):
            // Trashing is the default action, so Return takes it. It can't also be red: SwiftUI
            // paints the default button blue whatever role it has, and AppKit refuses to give a
            // red destructive button the Return key at all.
            Button(role: .destructive) {
                MediaConversion.finishConversion(cleanup, trashingOriginal: true)
            } label: {
                Text("Move to Trash", comment: "Alert button that trashes the original file")
            }
            .keyboardShortcut(.defaultAction)
            // The cancel role is what gives Escape somewhere to go.
            Button(role: .cancel) {
                MediaConversion.finishConversion(cleanup, trashingOriginal: false)
            } label: {
                Text("Keep", comment: "Alert button that leaves the original file where it is")
            }
        case .problem(let problem):
            ForEach(RemuxProblemAlert.buttons(for: problem.reason), id: \.self) { button in
                RemuxProblemButton(button)
            }
        }
    }
}

private struct RemuxAlertMessage: View {
    let alert: RemuxAlert

    var body: some View {
        switch alert {
        case .offer(let offer):
            RemuxOfferMessage(offer: offer)
        case .cleanup(let cleanup):
            Text(
                "\"\(cleanup.originalURL.lastPathComponent)\" was converted to \"\(cleanup.convertedURL.lastPathComponent)\". The original file isn't needed anymore and can be moved to trash.",
                comment: "Alert message shown after a file has been converted"
            )
        case .problem(let problem):
            RemuxProblemMessage(problem: problem)
        }
    }
}
