//
//  MediaFormatNames.swift
//  Front Row
//
//  Created by Joshua Park on 8/8/26.
//

import AudioToolbox
import CoreAudio
import CoreMedia
import Foundation

/// Turns the raw identifiers AVFoundation reports - four-character codes, CoreVideo colour
/// constants, channel layout tags - into something worth showing in the Inspector.
///
/// Kept free of AVFoundation objects so it can be tested without a media file.
enum MediaFormatNames {

    /// Renders a four-character code as text, dropping the padding spaces the shorter ones carry
    /// (`aac ` is written with a trailing space).
    static func fourCC(_ code: FourCharCode) -> String {
        let bytes = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF),
        ]
        guard let text = String(bytes: bytes, encoding: .macOSRoman) else { return "" }
        return text.trimmingCharacters(in: .whitespaces)
    }

    private static let videoCodecNames: [String: String] = [
        "hvc1": "H.265 / HEVC (High Efficiency Video Coding)",
        "hev1": "H.265 / HEVC (High Efficiency Video Coding)",
        "dvh1": "Dolby Vision (HEVC)",
        "dvhe": "Dolby Vision (HEVC)",
        "avc1": "H.264 / AVC (Advanced Video Coding)",
        "avc3": "H.264 / AVC (Advanced Video Coding)",
        "av01": "AV1 (AOMedia Video 1)",
        "vp09": "VP9",
        "mp4v": "MPEG-4 Part 2 Visual",
        "mp1v": "MPEG-1 Video",
        "mp2v": "MPEG-2 Video",
        "jpeg": "Motion JPEG",
        "apch": "Apple ProRes 422 HQ",
        "apcn": "Apple ProRes 422",
        "apcs": "Apple ProRes 422 LT",
        "apco": "Apple ProRes 422 Proxy",
        "ap4h": "Apple ProRes 4444",
        "ap4x": "Apple ProRes 4444 XQ",
    ]

    /// The readable name for a video codec, falling back to the code itself for anything not
    /// listed. Video has no system-provided lookup the way audio does.
    static func videoCodecName(for subType: FourCharCode) -> String {
        let code = fourCC(subType)
        return videoCodecNames[code] ?? code
    }

    /// Reads a CoreAudio property whose value is a string the caller then owns.
    private static func copyStringProperty(
        _ property: AudioFormatPropertyID,
        specifier: UnsafeRawPointer,
        specifierSize: Int
    ) -> String? {
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &name) {
            AudioFormatGetProperty(property, UInt32(specifierSize), specifier, &size, $0)
        }

        guard status == noErr, let name else { return nil }
        return name.takeRetainedValue() as String
    }

    /// The readable name CoreAudio gives an audio codec, such as `MPEG-4 AAC` or `Dolby Digital
    /// Plus`. Falls back to the four-character code for formats it doesn't recognise.
    static func audioCodecName(for formatID: AudioFormatID) -> String {
        var description = AudioStreamBasicDescription()
        description.mFormatID = formatID

        let name = withUnsafePointer(to: &description) {
            copyStringProperty(
                kAudioFormatProperty_FormatName,
                specifier: $0,
                specifierSize: MemoryLayout<AudioStreamBasicDescription>.size
            )
        }
        return name ?? fourCC(formatID)
    }

    /// The readable name for a channel layout, such as `5.1 (C L R Ls Rs LFE)`. Layouts CoreAudio
    /// can't name - and tracks with no layout at all - fall back to a plain channel count.
    static func channelLayoutName(
        for layout: ManagedAudioChannelLayout?, channelCount: UInt32
    ) -> String {
        guard let layout else { return channelCountDescription(channelCount) }

        let name = layout.withUnsafePointer { pointer in
            // The struct declares one channel description inline and the rest trail it, so the
            // real size depends on how many there are. `sizeInBytes` would say this too, but it
            // traps on the layouts files most often carry - a standard tag and no descriptions.
            let descriptions = Int(pointer.pointee.mNumberChannelDescriptions)
            let size =
                MemoryLayout<AudioChannelLayout>.size
                + max(0, descriptions - 1) * MemoryLayout<AudioChannelDescription>.size

            return copyStringProperty(
                kAudioFormatProperty_ChannelLayoutName,
                specifier: pointer,
                specifierSize: size
            )
        }
        return name ?? channelCountDescription(channelCount)
    }

    private static func channelCountDescription(_ count: UInt32) -> String {
        switch count {
        case 0: return String(localized: "Unknown", comment: "Inspector value for a missing field")
        case 1: return String(localized: "Mono", comment: "Single-channel audio")
        case 2: return String(localized: "Stereo", comment: "Two-channel audio")
        default:
            return String(
                localized: "\(count.formatted(.number)) channels",
                comment: "Audio channel count when the layout has no name"
            )
        }
    }

    private static let colourNames: [String: String] = [
        "ITU_R_709_2": "ITU-R BT.709",
        "ITU_R_601_4": "ITU-R BT.601",
        "ITU_R_2020": "ITU-R BT.2020",
        "ITU_R_2100_HLG": "ITU-R BT.2100 HLG",
        "SMPTE_C": "SMPTE C",
        "SMPTE_240M_1995": "SMPTE 240M",
        "SMPTE_ST_2084_PQ": "SMPTE ST 2084 (PQ)",
        "SMPTE_ST_428_1": "SMPTE ST 428-1",
        "DCI_P3": "DCI-P3",
        "P3_D65": "Display P3",
        "EBU_3213": "EBU 3213",
        "Linear": "Linear",
        "sRGB": "sRGB",
        "sYCC": "sYCC",
        "IEC_sRGB": "IEC sRGB",
        "UseGamma": "Gamma",
    ]

    /// Rewrites a CoreVideo colour constant - primaries, transfer function, or matrix - the way
    /// the standard is normally written. Unrecognised constants pass through as-is.
    static func colourName(for constant: String) -> String {
        colourNames[constant] ?? constant
    }

    /// The clockwise rotation a video track's preferred transform applies, in degrees.
    static func rotationDegrees(for transform: CGAffineTransform) -> Int {
        let radians = atan2(transform.b, transform.a)
        let degrees = Int((radians * 180 / .pi).rounded())
        return (degrees + 360) % 360
    }
}
