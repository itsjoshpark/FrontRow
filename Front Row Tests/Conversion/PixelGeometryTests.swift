//
//  PixelGeometryTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

struct PixelGeometryTests {

    /// Values are ffprobe's, from `ffprobe -show_pixel_formats`: `log2_chroma_w` and
    /// `log2_chroma_h` of 1 and 1 is 4:2:0, 1 and 0 is 4:2:2, 0 and 0 is 4:4:4.
    @Test(arguments: [
        ("yuv420p", PixelGeometry(chroma: .yuv420, depth: 8)),
        ("yuvj420p", PixelGeometry(chroma: .yuv420, depth: 8)),
        ("yuv420p10le", PixelGeometry(chroma: .yuv420, depth: 10)),
        ("yuv420p12le", PixelGeometry(chroma: .yuv420, depth: 12)),
        ("yuv422p", PixelGeometry(chroma: .yuv422, depth: 8)),
        ("yuvj422p", PixelGeometry(chroma: .yuv422, depth: 8)),
        ("yuv422p10le", PixelGeometry(chroma: .yuv422, depth: 10)),
        ("yuv444p", PixelGeometry(chroma: .yuv444, depth: 8)),
        ("yuv444p10le", PixelGeometry(chroma: .yuv444, depth: 10)),
        ("yuv411p", PixelGeometry(chroma: .yuv411, depth: 8)),
        ("gray", PixelGeometry(chroma: .monochrome, depth: 8)),
        ("gray10le", PixelGeometry(chroma: .monochrome, depth: 10)),
    ])
    func aFormatReportsTheChromaAndDepthFfprobeGivesIt(
        name: String, expected: PixelGeometry
    ) {
        #expect(PixelGeometry.named(name) == expected)
    }

    /// The two the old substring rule got wrong in opposite directions: `yuv410p` was read as
    /// 10-bit for containing "10", and `gbrp10le` slipped through as if it weren't 4:4:4.
    @Test
    func theFormatsASubstringRuleMisreads() {
        #expect(PixelGeometry.named("yuv410p") == PixelGeometry(chroma: .yuv410, depth: 8))
        #expect(PixelGeometry.named("gbrp10le") == PixelGeometry(chroma: .rgb, depth: 10))
    }

    @Test
    func anUnlistedFormatHasNoGeometry() {
        #expect(PixelGeometry.named("yuv420p14le") == nil)
        #expect(PixelGeometry.named("") == nil)
    }
}
