//
//  ConversionProgressSheet.swift
//  Front Row
//
//  Created by Joshua Park on 8/16/26.
//

import AppKit

/// The sheet shown while ffmpeg is converting a file.
///
/// An `NSAlert` rather than a SwiftUI overlay: this needs a progress indicator and a live-updating
/// label, neither of which a SwiftUI `alert` can hold, and being a real sheet it sits with the
/// window instead of being painted inside it.
@MainActor
final class ConversionProgressSheet {

    /// Wide enough for the longest percentage without the row drifting as the digits change.
    private static let accessoryWidth: CGFloat = 220
    private static let rowHeight: CGFloat = 16
    private static let spinnerWidth: CGFloat = 16
    private static let gap: CGFloat = 6

    private let alert = NSAlert()
    private let spinner = NSProgressIndicator()
    private let percentLabel = NSTextField(labelWithString: "")
    private let accessory = NSView(
        frame: NSRect(x: 0, y: 0, width: accessoryWidth, height: rowHeight))
    private weak var hostWindow: NSWindow?
    private var onCancel: (() -> Void)?
    private var dismissContinuation: CheckedContinuation<Void, Never>?
    private var isShowing = false

    /// The sheet shown while a conversion runs, with a button that stops it.
    convenience init(fileName: String) {
        self.init(
            messageText: String(
                localized: "Converting “\(fileName)”",
                comment: "Title of the sheet shown while a file is being converted"
            ),
            buttonTitle: String(
                localized: "Cancel",
                comment: "Button that stops a conversion that is running"
            )
        )
    }

    /// The sheet shown while a file is being checked over, before anything has been offered.
    convenience init(checkingFileName fileName: String) {
        self.init(
            messageText: String(
                localized: "Checking “\(fileName)”",
                comment: "Title of the sheet shown while a file is being examined"
            ),
            buttonTitle: String(
                localized: "Cancel",
                comment: "Button that stops a file being checked"
            )
        )
    }

    init(messageText: String, buttonTitle: String) {
        alert.messageText = messageText
        alert.addButton(withTitle: buttonTitle)

        // Indeterminate throughout. ffmpeg reports position roughly twice a second and not at all
        // for a file whose duration ffprobe couldn't measure, so a spinner is the honest constant
        // and the percentage is the extra.
        spinner.style = .spinning
        spinner.isIndeterminate = true
        spinner.controlSize = .small
        spinner.frame = NSRect(x: 0, y: 0, width: Self.spinnerWidth, height: Self.rowHeight)
        spinner.startAnimation(nil)

        percentLabel.font = .monospacedDigitSystemFont(
            ofSize: NSFont.smallSystemFontSize, weight: .regular)
        percentLabel.textColor = .secondaryLabelColor
        percentLabel.isHidden = true

        accessory.addSubview(spinner)
        accessory.addSubview(percentLabel)
        alert.accessoryView = accessory
        layoutRow()
    }

    /// Centres the spinner and the percentage as one group, so the row sits under the centred title
    /// rather than starting at the accessory's left edge.
    private func layoutRow() {
        percentLabel.sizeToFit()
        let labelWidth = percentLabel.isHidden ? 0 : percentLabel.frame.width
        let rowWidth = Self.spinnerWidth + (labelWidth > 0 ? Self.gap + labelWidth : 0)
        let left = ((Self.accessoryWidth - rowWidth) / 2).rounded()

        spinner.frame.origin.x = left
        percentLabel.frame.origin = CGPoint(
            x: left + Self.spinnerWidth + Self.gap,
            y: ((Self.rowHeight - percentLabel.frame.height) / 2).rounded()
        )
    }

    /// Shows the sheet on `window`. `onCancel` runs if the user stops the conversion.
    func present(on window: NSWindow, onCancel: @escaping () -> Void) {
        guard !isShowing else { return }
        isShowing = true
        hostWindow = window
        self.onCancel = onCancel

        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            isShowing = false
            if response == .alertFirstButtonReturn {
                self.onCancel?()
            }
            dismissContinuation?.resume()
            dismissContinuation = nil
        }
    }

    func update(fraction: Double) {
        percentLabel.stringValue = fraction.formatted(.percent.precision(.fractionLength(0)))
        percentLabel.isHidden = false
        layoutRow()
    }

    /// Closes the sheet and returns once AppKit has finished tearing it down.
    ///
    /// Awaited rather than fire-and-forget because whatever is raised next lands on the same
    /// window, and a SwiftUI alert presented while a sheet is still closing is dropped.
    func dismiss() async {
        guard isShowing, let hostWindow else { return }
        await withCheckedContinuation { continuation in
            dismissContinuation = continuation
            hostWindow.endSheet(alert.window)
        }
    }
}
