//
//  VideoWindowLayout.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import Foundation

/// Works out where a window showing video belongs, independent of `NSWindow` so it can be tested
/// directly.
enum VideoWindowLayout {

    /// The frame that shows `videoSize` centered in `screenFrame`, at its natural size when it
    /// fits and shrunk to the screen when it doesn't.
    ///
    /// Returns `nil` when there is no video to size to, which is the caller's cue to drop the
    /// window's aspect-ratio constraint rather than move it anywhere.
    static func frame(forVideoSize videoSize: CGSize, in screenFrame: CGRect) -> CGRect? {
        guard videoSize != .zero else { return nil }

        let fitsOnScreen =
            videoSize.width < screenFrame.width && videoSize.height < screenFrame.height
        let fittedSize = fitsOnScreen ? videoSize : videoSize.shrink(toSize: screenFrame.size)

        let origin = CGPoint(
            x: screenFrame.origin.x + (screenFrame.width - fittedSize.width) / 2,
            y: screenFrame.origin.y + (screenFrame.height - fittedSize.height) / 2
        )
        return CGRect(origin: origin, size: fittedSize)
    }
}

extension NSSize {
    var aspect: CGFloat {
        assert(width != 0 && height != 0)
        return width / height
    }

    /// Given another size S, returns a size that:

    /// - maintains the same aspect ratio;
    /// - has same height or/and width as S;
    /// - always smaller than S.

    /// - parameter toSize: The given size S.

    /// ```
    /// +--+------+--+
    /// |  |The   |  |
    /// |  |result|  |<-- S
    /// |  |size  |  |
    /// +--+------+--+
    /// ```
    func shrink(toSize size: NSSize) -> NSSize {
        if width == 0 || height == 0 {
            return size
        }
        let sizeAspect = size.aspect
        if aspect < sizeAspect {  // self is taller, shrink to meet height
            return NSSize(width: size.height * aspect, height: size.height)
        } else {
            return NSSize(width: size.width, height: size.width / aspect)
        }
    }
}
