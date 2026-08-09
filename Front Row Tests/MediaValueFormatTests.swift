//
//  MediaValueFormatTests.swift
//  Front Row Tests
//

import CoreMedia
import Foundation
import Testing

@testable import Front_Row

struct MediaValueFormatTests {

    /// A rate is only readable in the unit it belongs in - `5997797 bps` tells you nothing at a
    /// glance.
    @Test
    func bitRatesUseTheUnitTheyBelongIn() {
        #expect(MediaValueFormat.bitRate(5_997_797) == "6 Mbps")
        #expect(MediaValueFormat.bitRate(384_000) == "384 kbps")
        #expect(MediaValueFormat.bitRate(800) == "800 bps")
    }

    @Test
    func sampleRatesAreShownInKilohertz() {
        #expect(MediaValueFormat.sampleRate(48000) == "48 kHz")
        #expect(MediaValueFormat.sampleRate(44100) == "44.1 kHz")
    }

    /// 23.976 and 24 are different files, so the decimals have to survive.
    @Test
    func frameRatesKeepTheirDecimals() {
        #expect(MediaValueFormat.frameRate(23.976025) == "23.976 fps")
        #expect(MediaValueFormat.frameRate(24) == "24 fps")
    }

    /// A resolution is an identifier, not a quantity - grouping separators would make 3840 read as
    /// a measurement.
    @Test
    func dimensionsAreNotGrouped() {
        #expect(MediaValueFormat.dimensions(CGSize(width: 3840, height: 2076)) == "3840 × 2076")
    }

    /// The hour only appears once there is one, and a fractional second rounds to the nearest -
    /// both inherited from the timecode the seek bar already uses.
    @Test
    func durationsAreShownAsTimecode() {
        #expect(MediaValueFormat.duration(5833.834) == "1:37:14")
        #expect(MediaValueFormat.duration(125) == "02:05")
    }

    /// A chapter list has to line up, so each position is padded to the length of the whole file.
    /// Padding each to its own magnitude would give a two-hour film `00:30` near the start and
    /// `1:05:00` further down.
    @Test
    func positionsArePaddedToTheWholeFile() {
        #expect(MediaValueFormat.position(30, in: 7200) == "0:00:30")
        #expect(MediaValueFormat.position(30, in: 300) == "00:30")
    }

    @Test
    func bitDepthAndRotationReadAsUnits() {
        #expect(MediaValueFormat.bitDepth(10) == "10-bit")
        #expect(MediaValueFormat.rotation(90) == "90°")
    }

    private func track(
        id: CMPersistentTrackID = 1,
        kind: TrackKind = .video,
        formatCode: String? = nil,
        dimensions: CGSize? = nil,
        frameRate: Double? = nil,
        channels: String? = nil,
        languageName: String? = nil
    ) -> TrackSummary {
        TrackSummary(
            id: id,
            kind: kind,
            formatCode: formatCode,
            codecName: nil,
            isEnabled: true,
            isSelected: true,
            isMainProgram: true,
            isForced: false,
            title: nil,
            languageName: languageName,
            dataSize: nil,
            dimensions: dimensions,
            frameRate: frameRate,
            channels: channels,
            sampleRate: nil,
            bitRate: nil
        )
    }

    /// The picker label has to name whatever tells one track apart from its siblings, which
    /// differs by media type.
    @Test
    func aTrackLabelNamesWhatDistinguishesTheTrack() {
        let video = track(
            id: 1, kind: .video, formatCode: "hvc1",
            dimensions: CGSize(width: 3840, height: 2076), frameRate: 23.976025)

        #expect(
            MediaValueFormat.trackLabel(for: video) == "Video #1 — hvc1, 3840 × 2076, 23.976 fps")
    }

    @Test
    func anAudioTrackLabelNamesItsLayout() {
        let audio = track(id: 2, kind: .audio, formatCode: "aac", channels: "5.1")

        #expect(MediaValueFormat.trackLabel(for: audio) == "Audio #2 — aac, 5.1")
    }

    /// A track AVFoundation told us nothing about still needs a name to be selectable by.
    @Test
    func aTrackWithNoDetailsIsStillNamed() {
        #expect(MediaValueFormat.trackLabel(for: track(id: 3, kind: .subtitle)) == "Subtitle #3")
    }
}
