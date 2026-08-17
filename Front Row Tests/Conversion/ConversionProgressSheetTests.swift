//
//  ConversionProgressSheetTests.swift
//  Front Row Tests
//

import AppKit
import Testing

@testable import Front_Row

/// The sheet shown while ffmpeg works.
///
/// `MediaConversion` awaits `dismiss()` before raising whatever comes next, so a dismissal that
/// never returns is a hang with a spinner on top of it - the shape of failure hardest to
/// recognise as a bug.
/// Serialized: these put real sheets on real windows, and AppKit has one main run loop to do it
/// on.
@MainActor
@Suite(.serialized)
struct ConversionProgressSheetTests {

    /// A window that stays alive as long as the test holds it.
    ///
    /// `isReleasedWhenClosed` defaults to true for a window built in code, which under ARC frees
    /// it a second time and takes the process down somewhere else entirely.
    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 270),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        )
        window.isReleasedWhenClosed = false
        return window
    }

    /// A conversion started with no window to hang the sheet from never presents one, and the
    /// task still awaits `dismiss()` on its way out.
    @Test(.timeLimit(.minutes(1)))
    func dismissingASheetThatWasNeverPresentedReturns() async {
        let sheet = ConversionProgressSheet(fileName: "film.mkv")
        await sheet.dismiss()
    }

    @Test(.timeLimit(.minutes(1)))
    func dismissingAPresentedSheetReturns() async {
        let window = makeWindow()
        window.orderFront(nil)
        defer { window.orderOut(nil) }

        let sheet = ConversionProgressSheet(fileName: "film.mkv")
        sheet.present(on: window) {}

        await sheet.dismiss()

        #expect(window.attachedSheet == nil)
    }

    /// Dismissing twice is what a cancelled conversion does when the failure path also tidies up.
    /// The second must not wait on a continuation nothing will resume.
    @Test(.timeLimit(.minutes(1)))
    func dismissingTwiceReturns() async {
        let window = makeWindow()
        window.orderFront(nil)
        defer { window.orderOut(nil) }

        let sheet = ConversionProgressSheet(fileName: "film.mkv")
        sheet.present(on: window) {}

        await sheet.dismiss()
        await sheet.dismiss()
    }

    /// Progress can arrive before the sheet is on screen - ffmpeg starts reporting as soon as it
    /// is launched, and the sheet is presented from a later turn.
    @Test(.timeLimit(.minutes(1)))
    func progressBeforePresentingIsHarmless() async {
        let sheet = ConversionProgressSheet(fileName: "film.mkv")
        sheet.update(fraction: 0.5)
        await sheet.dismiss()
    }

    @Test(.timeLimit(.minutes(1)))
    func presentingTwiceLeavesOneSheet() async {
        let window = makeWindow()
        window.orderFront(nil)
        defer { window.orderOut(nil) }

        let sheet = ConversionProgressSheet(fileName: "film.mkv")
        sheet.present(on: window) {}
        sheet.present(on: window) {}

        #expect(window.attachedSheet != nil)
        await sheet.dismiss()
        #expect(window.attachedSheet == nil)
    }
}
