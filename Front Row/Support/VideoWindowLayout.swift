//
//  VideoWindowLayout.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import Foundation

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
