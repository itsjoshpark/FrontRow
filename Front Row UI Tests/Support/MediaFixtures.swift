//
//  MediaFixtures.swift
//  Front Row UI Tests
//

import AVFoundation
import CoreImage

/// Writes throwaway media files for the UI tests to open.
///
/// Written with `AVAssetWriter` rather than shipped as checked-in files: the tests need several
/// specific pixel dimensions, and a generator states the dimension that matters in the test
/// rather than hiding it in a binary.
enum MediaFixtures {

    /// Where a run's fixtures live. Removed wholesale in `tearDown`.
    ///
    /// Under caches rather than the temporary directory, which sits below `/var` - a link to
    /// `/private/var`. A bookmark records a file there as `/private/var/…` while
    /// `resolvingSymlinksInPath()` calls it `/var/…`, so recent documents opened from there never
    /// match themselves and pile up duplicates. That is a property of the path, not of the app.
    static func makeDirectory() throws -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = caches.appending(path: "FrontRowUITests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// A silent H.264 movie of `size`, three seconds long.
    ///
    /// The frames are a flat colour that shifts over time. Nothing reads the picture - the tests
    /// are about the shape of the window around it - so the cheapest thing that encodes will do.
    /// - Parameter frameRate: Frames written per second of playback. Lowered where a test needs a
    ///   long file and doesn't care what it looks like, since every frame costs encoding time.
    static func makeMovie(
        size: CGSize,
        named name: String,
        in directory: URL,
        seconds: Int = 3,
        frameRate: Int = 30
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

        let frameCount = seconds * frameRate

        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }
            guard let pool = adaptor.pixelBufferPool else {
                throw FixtureError.noPixelBufferPool
            }
            let buffer = try makePixelBuffer(pool: pool, shade: Double(frame) / Double(frameCount))
            let time = CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(frameRate))
            adaptor.append(buffer, withPresentationTime: time)
        }

        input.markAsFinished()
        await writer.finishWriting()

        guard writer.status == .completed else {
            throw writer.error ?? FixtureError.writeFailed
        }
        return url
    }

    /// A silent audio-only file, for the case where there is no video to shape a window to.
    static func makeAudioOnly(named name: String, in directory: URL, seconds: Int = 3) async throws
        -> URL
    {
        let url = directory.appending(path: "\(name).m4a")
        let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)

        let sampleRate = 44_100.0
        let input = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 64_000,
            ]
        )
        input.expectsMediaDataInRealTime = false

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let framesPerChunk = AVAudioFrameCount(sampleRate)

        for second in 0..<seconds {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }
            let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesPerChunk)!
            pcm.frameLength = framesPerChunk
            // Silence is enough; nothing listens.
            pcm.floatChannelData?[0].update(repeating: 0, count: Int(framesPerChunk))

            guard
                let sample = pcm.asSampleBuffer(
                    at: CMTime(value: CMTimeValue(second), timescale: 1))
            else {
                throw FixtureError.writeFailed
            }
            input.append(sample)
        }

        input.markAsFinished()
        await writer.finishWriting()

        guard writer.status == .completed else {
            throw writer.error ?? FixtureError.writeFailed
        }
        return url
    }

    private static func makePixelBuffer(pool: CVPixelBufferPool, shade: Double) throws
        -> CVPixelBuffer
    {
        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
            let buffer
        else {
            throw FixtureError.noPixelBufferPool
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        if let base = CVPixelBufferGetBaseAddress(buffer) {
            let size = CVPixelBufferGetBytesPerRow(buffer) * CVPixelBufferGetHeight(buffer)
            memset(base, Int32(shade * 200) + 20, size)
        }
        return buffer
    }

    enum FixtureError: Error {
        case noPixelBufferPool
        case writeFailed
    }
}

extension AVAudioPCMBuffer {
    /// Wraps the PCM data as a `CMSampleBuffer` so an `AVAssetWriterInput` will take it.
    fileprivate func asSampleBuffer(at time: CMTime) -> CMSampleBuffer? {
        var format: CMFormatDescription?
        guard
            CMAudioFormatDescriptionCreate(
                allocator: kCFAllocatorDefault,
                asbd: self.format.streamDescription,
                layoutSize: 0,
                layout: nil,
                magicCookieSize: 0,
                magicCookie: nil,
                extensions: nil,
                formatDescriptionOut: &format
            ) == noErr, let format
        else { return nil }

        var sampleBuffer: CMSampleBuffer?
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(self.format.sampleRate)),
            presentationTimeStamp: time,
            decodeTimeStamp: .invalid
        )

        guard
            CMSampleBufferCreate(
                allocator: kCFAllocatorDefault,
                dataBuffer: nil,
                dataReady: false,
                makeDataReadyCallback: nil,
                refcon: nil,
                formatDescription: format,
                sampleCount: CMItemCount(frameLength),
                sampleTimingEntryCount: 1,
                sampleTimingArray: &timing,
                sampleSizeEntryCount: 0,
                sampleSizeArray: nil,
                sampleBufferOut: &sampleBuffer
            ) == noErr, let sampleBuffer
        else { return nil }

        guard
            CMSampleBufferSetDataBufferFromAudioBufferList(
                sampleBuffer,
                blockBufferAllocator: kCFAllocatorDefault,
                blockBufferMemoryAllocator: kCFAllocatorDefault,
                flags: 0,
                bufferList: audioBufferList
            ) == noErr
        else { return nil }

        return sampleBuffer
    }
}
