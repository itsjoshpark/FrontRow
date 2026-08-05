//
//  VideoWindowLayoutTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

struct VideoWindowLayoutTests {

    private let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)

    @Test
    func videoSmallerThanTheScreenIsShownAtItsNaturalSizeAndCentered() {
        let frame = VideoWindowLayout.frame(
            forVideoSize: CGSize(width: 400, height: 300), in: screen)

        #expect(frame == CGRect(x: 300, y: 250, width: 400, height: 300))
    }

    /// The screen's own origin has to be carried through, or a video on a secondary display lands
    /// on the primary one.
    @Test
    func theScreensOriginIsHonored() {
        let offsetScreen = CGRect(x: 1440, y: 100, width: 1000, height: 800)

        let frame = VideoWindowLayout.frame(
            forVideoSize: CGSize(width: 400, height: 300), in: offsetScreen)

        #expect(frame == CGRect(x: 1740, y: 350, width: 400, height: 300))
    }

    @Test
    func videoWiderThanTheScreenShrinksToItsWidth() {
        let frame = VideoWindowLayout.frame(
            forVideoSize: CGSize(width: 3840, height: 2160), in: screen)

        #expect(frame == CGRect(x: 0, y: 118.75, width: 1000, height: 562.5))
    }

    @Test
    func videoTallerThanTheScreenShrinksToItsHeight() {
        let frame = VideoWindowLayout.frame(
            forVideoSize: CGSize(width: 1080, height: 1920), in: screen)

        #expect(frame == CGRect(x: 275, y: 0, width: 450, height: 800))
    }

    /// Shrinking must not distort the picture, whichever edge it was constrained by.
    @Test
    func shrinkingPreservesTheAspectRatio() {
        for videoSize in [CGSize(width: 3840, height: 2160), CGSize(width: 1080, height: 1920)] {
            let frame = VideoWindowLayout.frame(forVideoSize: videoSize, in: screen)!

            #expect(
                abs(frame.width / frame.height - videoSize.width / videoSize.height) < 0.0001)
        }
    }

    /// No video means there is nothing to size to, which is the caller's cue to drop the window's
    /// aspect-ratio constraint rather than move it.
    @Test
    func noVideoHasNoFrame() {
        #expect(VideoWindowLayout.frame(forVideoSize: .zero, in: screen) == nil)
    }
}
