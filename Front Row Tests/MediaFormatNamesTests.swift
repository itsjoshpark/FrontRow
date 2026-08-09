//
//  MediaFormatNamesTests.swift
//  Front Row Tests
//

import CoreAudio
import CoreAudioTypes
import CoreMedia
import Foundation
import Testing

@testable import Front_Row

struct MediaFormatNamesTests {

    private func code(_ text: String) -> FourCharCode {
        text.utf8.reduce(0) { ($0 << 8) | FourCharCode($1) }
    }

    /// Codes shorter than four characters are padded with spaces in the file, which shouldn't
    /// reach the screen.
    @Test
    func fourCharacterCodesAreReadAndTrimmed() {
        #expect(MediaFormatNames.fourCC(code("hvc1")) == "hvc1")
        #expect(MediaFormatNames.fourCC(code("aac ")) == "aac")
    }

    @Test
    func knownVideoCodecsGetTheirFullName() {
        #expect(
            MediaFormatNames.videoCodecName(for: code("hvc1"))
                == "H.265 / HEVC (High Efficiency Video Coding)")
        #expect(
            MediaFormatNames.videoCodecName(for: code("avc1"))
                == "H.264 / AVC (Advanced Video Coding)")
    }

    /// An unmapped codec still has to say something useful, so the raw code stands in for a name.
    @Test
    func anUnknownVideoCodecFallsBackToItsCode() {
        #expect(MediaFormatNames.videoCodecName(for: code("zzzz")) == "zzzz")
    }

    @Test
    func audioCodecsAreNamedByCoreAudio() {
        #expect(MediaFormatNames.audioCodecName(for: kAudioFormatMPEG4AAC) == "MPEG-4 AAC")
        #expect(MediaFormatNames.audioCodecName(for: kAudioFormatAC3) == "Dolby Digital")
    }

    @Test
    func anUnknownAudioCodecFallsBackToItsCode() {
        #expect(MediaFormatNames.audioCodecName(for: code("zzzz")) == "zzzz")
    }

    @Test
    func aChannelLayoutIsNamedByCoreAudio() {
        let layout = ManagedAudioChannelLayout(tag: kAudioChannelLayoutTag_MPEG_5_1_A)

        let name = MediaFormatNames.channelLayoutName(for: layout, channelCount: 6)

        #expect(name.hasPrefix("5.1"))
    }

    /// What an MP4 actually carries: a standard tag and no channel descriptions at all. Sizing
    /// such a layout by counting its descriptions has to survive there being none.
    @Test
    func aTagOnlyLayoutWithNoDescriptionsIsNamed() {
        let storage = UnsafeMutablePointer<AudioChannelLayout>.allocate(capacity: 1)
        storage.initialize(to: AudioChannelLayout())
        storage.pointee.mChannelLayoutTag = kAudioChannelLayoutTag_MPEG_5_1_A
        storage.pointee.mNumberChannelDescriptions = 0

        let layout = ManagedAudioChannelLayout(
            audioChannelLayoutPointer: AudioChannelLayout.UnsafePointer(storage)
        ) { _ in storage.deallocate() }

        let name = MediaFormatNames.channelLayoutName(for: layout, channelCount: 6)

        #expect(name.hasPrefix("5.1"))
    }

    /// A layout spelled out channel by channel, which is what files carry when they don't use a
    /// standard tag.
    @Test
    func aChannelLayoutDescribedChannelByChannelIsRead() {
        let labels: [AudioChannelLabel] = [
            kAudioChannelLabel_Left, kAudioChannelLabel_Right, kAudioChannelLabel_Center,
            kAudioChannelLabel_LFEScreen, kAudioChannelLabel_LeftSurround,
            kAudioChannelLabel_RightSurround,
        ]
        let layout = ManagedAudioChannelLayout(
            channelDescriptions: labels.map {
                AudioChannelDescription(
                    mChannelLabel: $0, mChannelFlags: [], mCoordinates: (0, 0, 0))
            })

        let name = MediaFormatNames.channelLayoutName(for: layout, channelCount: 6)

        #expect(!name.isEmpty)
    }

    /// A track with no layout at all - common in raw streams - still has a channel count worth
    /// showing.
    @Test
    func aMissingLayoutFallsBackToTheChannelCount() {
        #expect(MediaFormatNames.channelLayoutName(for: nil, channelCount: 1) == "Mono")
        #expect(MediaFormatNames.channelLayoutName(for: nil, channelCount: 2) == "Stereo")
        #expect(MediaFormatNames.channelLayoutName(for: nil, channelCount: 6) == "6 channels")
    }

    @Test
    func colourConstantsAreRewrittenTheWayTheStandardIsWritten() {
        #expect(MediaFormatNames.colourName(for: "ITU_R_709_2") == "ITU-R BT.709")
        #expect(MediaFormatNames.colourName(for: "ITU_R_2020") == "ITU-R BT.2020")
        #expect(MediaFormatNames.colourName(for: "SMPTE_ST_2084_PQ") == "SMPTE ST 2084 (PQ)")
    }

    @Test
    func anUnknownColourConstantPassesThrough() {
        #expect(MediaFormatNames.colourName(for: "Some_New_Standard") == "Some_New_Standard")
    }

    @Test
    func theHDRCurveIsNamedByItsTransferFunction() {
        #expect(MediaFormatNames.hdrFormatName(forTransferFunction: "ITU_R_2100_HLG") == "HLG")
        #expect(MediaFormatNames.hdrFormatName(forTransferFunction: "SMPTE_ST_2084_PQ") == "PQ")
    }

    /// An SDR curve names no HDR format, which is what lets the HDR row fall back to a plain yes.
    @Test
    func anSDRTransferFunctionNamesNoHDRFormat() {
        #expect(MediaFormatNames.hdrFormatName(forTransferFunction: "ITU_R_709_2") == nil)
    }

    @Test
    func rotationIsReadFromThePreferredTransform() {
        #expect(MediaFormatNames.rotationDegrees(for: .identity) == 0)
        #expect(
            MediaFormatNames.rotationDegrees(for: CGAffineTransform(rotationAngle: .pi / 2)) == 90)
        #expect(MediaFormatNames.rotationDegrees(for: CGAffineTransform(rotationAngle: .pi)) == 180)
    }

    /// A quarter turn the other way is the same orientation as three quarters this way, and that's
    /// how it should read.
    @Test
    func rotationIsNormalisedToAFullTurn() {
        #expect(
            MediaFormatNames.rotationDegrees(for: CGAffineTransform(rotationAngle: -.pi / 2)) == 270
        )
    }
}
