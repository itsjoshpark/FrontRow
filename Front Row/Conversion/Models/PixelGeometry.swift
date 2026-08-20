//
//  PixelGeometry.swift
//  Front Row
//
//  Created by Joshua Park on 8/20/26.
//

import Foundation

/// The chroma subsampling and bit depth behind a pixel format's name.
///
/// `RemuxPlanner` decides on these two properties, and reading them from a table rather than from
/// the spelling of the name is the point: `yuv410p` contains "10" without being 10-bit, and
/// `gbrp10le` is 4:4:4 without saying so.
///
/// Values are ffprobe's own, from `ffprobe -show_pixel_formats` - `log2_chroma_w` and
/// `log2_chroma_h` give the subsampling, and a format with neither has no chroma planes at all.
struct PixelGeometry: Equatable, Sendable {

    enum Chroma: Equatable, Sendable {
        case monochrome
        case yuv410
        case yuv411
        case yuv420
        case yuv422
        case yuv444
        case rgb
    }

    var chroma: Chroma
    var depth: Int

    /// `nil` for a format not listed here, which the planner treats as a refusal.
    static func named(_ pixelFormat: String) -> PixelGeometry? {
        formats[pixelFormat]
    }

    /// What the codecs in `RemuxPlanner.copyableVideoCodecs` actually emit.
    ///
    /// The `yuvj` formats are the full-range counterparts of their `yuv` namesakes and differ only
    /// in range, which decoders do not refuse on.
    private static let formats: [String: PixelGeometry] = [
        "gray": PixelGeometry(chroma: .monochrome, depth: 8),
        "gray10le": PixelGeometry(chroma: .monochrome, depth: 10),
        "gray12le": PixelGeometry(chroma: .monochrome, depth: 12),

        "yuv410p": PixelGeometry(chroma: .yuv410, depth: 8),

        "yuv411p": PixelGeometry(chroma: .yuv411, depth: 8),
        "yuvj411p": PixelGeometry(chroma: .yuv411, depth: 8),

        "yuv420p": PixelGeometry(chroma: .yuv420, depth: 8),
        "yuvj420p": PixelGeometry(chroma: .yuv420, depth: 8),
        "yuv420p10le": PixelGeometry(chroma: .yuv420, depth: 10),
        "yuv420p12le": PixelGeometry(chroma: .yuv420, depth: 12),

        "yuv422p": PixelGeometry(chroma: .yuv422, depth: 8),
        "yuvj422p": PixelGeometry(chroma: .yuv422, depth: 8),
        "yuv422p10le": PixelGeometry(chroma: .yuv422, depth: 10),
        "yuv422p12le": PixelGeometry(chroma: .yuv422, depth: 12),

        "yuv444p": PixelGeometry(chroma: .yuv444, depth: 8),
        "yuvj444p": PixelGeometry(chroma: .yuv444, depth: 8),
        "yuv444p10le": PixelGeometry(chroma: .yuv444, depth: 10),
        "yuv444p12le": PixelGeometry(chroma: .yuv444, depth: 12),

        "gbrp": PixelGeometry(chroma: .rgb, depth: 8),
        "gbrp10le": PixelGeometry(chroma: .rgb, depth: 10),
        "gbrp12le": PixelGeometry(chroma: .rgb, depth: 12),
    ]
}
