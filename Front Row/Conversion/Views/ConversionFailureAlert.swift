//
//  ConversionFailureAlert.swift
//  Front Row
//
//  Created by Joshua Park on 8/16/26.
//

import AppKit

/// The alert shown when ffmpeg started a conversion and gave up.
///
/// An `NSAlert` so ffmpeg's own output can sit behind a disclosure triangle: collapsed it stays out
/// of the way of someone who only needs to know it failed, expanded it gives someone filing a bug
/// report the whole thing to copy.
@MainActor
enum ConversionFailureAlert {

    static func present(fileName: String, details: String, on window: NSWindow?) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(
            localized: "Couldn't Convert File",
            comment: "Alert title shown when ffmpeg failed"
        )
        alert.informativeText = String(
            localized: "FFmpeg couldn't convert “\(fileName)”.",
            comment: "Alert message shown when ffmpeg failed to convert a file"
        )
        alert.addButton(
            withTitle: String(
                localized: "OK",
                comment: "Dismisses the alert shown when a file couldn't be converted"
            )
        )

        if !details.isEmpty {
            alert.accessoryView = DisclosureAccessory(alert: alert, details: details)
        }

        if let window {
            alert.beginSheetModal(for: window) { _ in }
        } else {
            alert.runModal()
        }
    }
}

/// A disclosure triangle above a scrolling copy of ffmpeg's output, sized to collapse away when
/// closed so the alert is no taller than it needs to be.
private final class DisclosureAccessory: NSView {

    private static let width: CGFloat = 380
    private static let triangleHeight: CGFloat = 20
    private static let detailsHeight: CGFloat = 130

    private weak var alert: NSAlert?
    private let scrollView = NSScrollView()
    private let toggle = NSButton()
    private let caption = NSTextField(
        labelWithString: String(
            localized: "Details",
            comment: "Label on the disclosure triangle revealing ffmpeg's error output"
        )
    )

    init(alert: NSAlert, details: String) {
        self.alert = alert
        super.init(
            frame: NSRect(x: 0, y: 0, width: Self.width, height: Self.triangleHeight)
        )

        toggle.setButtonType(.onOff)
        toggle.bezelStyle = .disclosure
        toggle.title = ""
        toggle.state = .off
        toggle.target = self
        toggle.action = #selector(toggleDetails(_:))
        toggle.frame = NSRect(x: 0, y: 0, width: 16, height: Self.triangleHeight)
        // The bezel draws a bare triangle, so the control has no label of its own to announce.
        toggle.setAccessibilityLabel(caption.stringValue)

        caption.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        caption.textColor = .secondaryLabelColor
        caption.frame = NSRect(x: 18, y: 2, width: 200, height: 16)

        let textView = NSTextView(
            frame: NSRect(x: 0, y: 0, width: Self.width, height: Self.detailsHeight)
        )
        textView.string = details
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)

        scrollView.frame = NSRect(x: 0, y: 0, width: Self.width, height: Self.detailsHeight)
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.isHidden = true

        // Without a role of its own the accessory is announced as one opaque element and neither
        // the triangle nor the output inside it can be reached.
        setAccessibilityRole(.group)

        addSubview(toggle)
        addSubview(caption)
        addSubview(scrollView)
        layoutContents(expanded: false)
    }

    /// Triangle above, output below. AppKit's origin is bottom-left, so the row has to be lifted
    /// clear of the scroll view rather than simply placed first.
    private func layoutContents(expanded: Bool) {
        let rowY = expanded ? Self.detailsHeight : 0
        toggle.frame.origin.y = rowY
        caption.frame.origin.y = rowY + 2
        scrollView.isHidden = !expanded
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func toggleDetails(_ sender: NSButton) {
        let isExpanded = sender.state == .on
        setFrameSize(
            NSSize(
                width: Self.width,
                height: Self.triangleHeight + (isExpanded ? Self.detailsHeight : 0)
            )
        )
        layoutContents(expanded: isExpanded)
        // Re-measures the alert around the accessory's new height; without it the sheet keeps its
        // old size and the output is revealed into nothing.
        alert?.layout()
    }
}
