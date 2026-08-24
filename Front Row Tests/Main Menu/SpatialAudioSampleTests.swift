//
//  SpatialAudioSampleTests.swift
//  Front Row Tests
//
//  Created by Joshua Park on 8/19/26.
//

import AVFoundation
import Foundation
import Testing

@testable import Front_Row

/// Whether the host serving the sample answers at all. Read outside the suite, since a trait
/// cannot ask the type it is attached to.
private let sampleHostAnswers = hostAnswers(for: AppCommands.spatialAudioSampleURL)

/// Whether a request for `url` came back with an HTTP response of any kind.
///
/// A 404 answers, and a withdrawn sample is exactly what the tests below are for, so only a
/// transport failure - no network, no DNS - counts as unreachable. Blocking rather than async
/// because a trait's condition is read synchronously.
private func hostAnswers(for url: URL) -> Bool {
    var request = URLRequest(url: url, timeoutInterval: 15)
    request.httpMethod = "HEAD"

    let answer = Answer()
    let finished = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: request) { _, response, _ in
        answer.record(response != nil)
        finished.signal()
    }.resume()
    _ = finished.wait(timeout: .now() + 30)

    return answer.value
}

/// Somewhere for the callback to leave its answer, read from outside the callback.
private final class Answer: @unchecked Sendable {
    private let lock = NSLock()
    private var answered = false

    func record(_ value: Bool) {
        lock.withLock { answered = value }
    }

    var value: Bool {
        lock.withLock { answered }
    }
}

/// The clip behind Front Row > Play Spatial Audio Sample.
///
/// It is the one thing the app plays that it does not ship and the user did not choose, so
/// whether the menu item works at all is somebody else's decision to make. These are the tests
/// that notice when it is made.
@Suite struct SpatialAudioSampleTests {

    /// The address itself, checked without a network so a mistyped edit is caught wherever the
    /// tests run.
    @Test func urlPointsAtTheDolbySample() {
        let url = AppCommands.spatialAudioSampleURL

        #expect(url.scheme == "https")
        #expect(url.host() == "media.developer.dolby.com")
        #expect(url.lastPathComponent == "MP4_HPL40_30fps_channel_id_51.mp4")
    }

    /// What is actually at that address today.
    ///
    /// Skipped where the machine cannot reach the host, which says nothing either way. Only the
    /// headers are fetched - the clip itself is some thirty megabytes.
    @Suite(.enabled(if: sampleHostAnswers))
    struct Hosted {

        @Test(.timeLimit(.minutes(1)))
        func sampleIsStillServed() async throws {
            var request = URLRequest(url: AppCommands.spatialAudioSampleURL, timeoutInterval: 30)
            request.httpMethod = "HEAD"

            let (_, response) = try await URLSession.shared.data(for: request)
            let http = try #require(response as? HTTPURLResponse)

            #expect(
                http.statusCode == 200,
                """
                The spatial audio sample answered \(http.statusCode), so the menu item has \
                nothing to play
                """
            )
            let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? ""
            #expect(
                contentType.hasPrefix("video/"),
                "The spatial audio sample is served as \(contentType) rather than a video"
            )
        }

        /// That the clip still has more channels than a pair of headphones has ears.
        ///
        /// Spatial audio needs more than two channels to place, so a stereo file at the same
        /// address would pass every other check here and leave the menu item promising something
        /// it no longer delivers.
        @Test(.timeLimit(.minutes(1)))
        func sampleIsPlayableAndMultichannel() async throws {
            let asset = AVURLAsset(url: AppCommands.spatialAudioSampleURL)

            let isPlayable = try await asset.load(.isPlayable)
            #expect(isPlayable, "AVFoundation will not play the spatial audio sample")

            let tracks = try await asset.loadTracks(withMediaType: .audio)
            let track = try #require(tracks.first, "The spatial audio sample has no audio track")
            let descriptions = try await track.load(.formatDescriptions)

            let channels =
                descriptions
                .compactMap { $0.audioStreamBasicDescription?.mChannelsPerFrame }
                .max() ?? 0
            #expect(
                channels > 2,
                """
                The spatial audio sample carries \(channels) audio channels, which is not \
                enough to place
                """
            )
        }

        /// That the Audio Track menu still finds the clip's audio.
        ///
        /// The sample's tracks sit in no alternate group, so AVFoundation offers no media
        /// selection group for them and the menu has to fall back to the tracks themselves. Both
        /// halves are asserted: a group appearing here would mean the fallback is no longer what
        /// this clip exercises.
        @Test(.timeLimit(.minutes(1)))
        @MainActor
        func audioIsOfferedWithoutAMediaSelectionGroup() async throws {
            let asset = AVURLAsset(url: AppCommands.spatialAudioSampleURL)

            let group = try await asset.loadMediaSelectionGroup(for: .audible)
            #expect(group == nil, "The spatial audio sample now groups its tracks after all")

            let choices = await MediaTrackChoice.choices(
                in: group, of: asset, mediaTypes: [.audio])
            #expect(choices.count == 1)
            #expect(choices.first?.name == "Track 1")
        }
    }
}
