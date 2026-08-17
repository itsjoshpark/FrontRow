//
//  PlaybackFixtures.swift
//  Front Row Tests
//
//  Created by Joshua Park on 8/17/26.
//

import AVFoundation
import Foundation

/// Throwaway media files for the tests that drive `PlayEngine` against a real asset.
///
/// The UI bundle has a fuller generator of its own. Test bundles can't share a file, and what the
/// in-process tests need is smaller: something that plays, and something that doesn't.
enum PlaybackFixtures {

    /// Where a test's fixtures live, removed by `remove(_:)` when it finishes.
    ///
    /// Under caches rather than the temporary directory, which sits below `/var` - a link to
    /// `/private/var`. A bookmark records a file there as `/private/var/…` while
    /// `resolvingSymlinksInPath()` calls it `/var/…`, so a recent document opened from there never
    /// matches itself.
    static func makeDirectory() throws -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = caches.appending(path: "FrontRowPlayback-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func remove(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }

    /// A silent H.264 movie of `size`. Flat grey frames at a low frame rate: nothing looks at the
    /// picture, and every frame costs encoding time on the way into each test.
    static func makeMovie(
        size: CGSize = CGSize(width: 320, height: 180),
        named name: String,
        in directory: URL,
        seconds: Int = 4,
        frameRate: Int = 4
    ) async throws -> URL {
        let url = directory.appending(path: "\(name).mp4")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(size.width),
                AVVideoHeightKey: Int(size.height),
            ]
        )
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
            ]
        )

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        for frame in 0..<(seconds * frameRate) {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }
            guard let pool = adaptor.pixelBufferPool else { throw FixtureError.noPixelBufferPool }
            let buffer = try makePixelBuffer(pool: pool)
            let time = CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(frameRate))
            adaptor.append(buffer, withPresentationTime: time)
        }

        input.markAsFinished()
        await writer.finishWriting()

        guard writer.status == .completed else { throw writer.error ?? FixtureError.writeFailed }
        return url
    }

    /// Bytes that are not a movie, under a name that says they are. The open panel and drag and
    /// drop both filter by type, so this is what a file that has been corrupted or truncated
    /// since it was last opened looks like on the way in.
    static func makeUnplayable(named name: String, in directory: URL) throws -> URL {
        let url = directory.appending(path: "\(name).mp4")
        try Data(repeating: 0xAB, count: 4_096).write(to: url)
        return url
    }

    private static func makePixelBuffer(pool: CVPixelBufferPool) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
            let buffer
        else {
            throw FixtureError.noPixelBufferPool
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        if let base = CVPixelBufferGetBaseAddress(buffer) {
            memset(base, 128, CVPixelBufferGetBytesPerRow(buffer) * CVPixelBufferGetHeight(buffer))
        }
        return buffer
    }

    enum FixtureError: Error {
        case noPixelBufferPool
        case writeFailed
    }
}
