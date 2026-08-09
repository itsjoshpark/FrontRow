//
//  InspectorGeneralTab.swift
//  Front Row
//
//  Created by Joshua Park on 8/8/26.
//

import SwiftUI

/// What the file is made of, at a glance: the video and audio the player actually chose, and the
/// colour pipeline the picture was encoded against.
struct InspectorGeneralTab: View {
    let inspection: MediaInspection

    var body: some View {
        InspectorForm {
            if let video = inspection.video {
                InspectorSectionHeader(
                    title: Text("Video", comment: "Inspector section heading"), isFirst: true)
                Group {
                    InspectorRow(label: Text("Format"), value: video.formatCode)
                    InspectorRow(label: Text("Codec"), value: video.codecName)
                    InspectorRow(label: Text("Encoder"), value: video.encoder)
                    InspectorRow(
                        label: Text("Hardware Decoding"),
                        value: video.isHardwareDecodeSupported
                            ? String(
                                localized: "Supported",
                                comment: "This Mac can decode the codec in hardware")
                            : String(
                                localized: "Not supported",
                                comment: "This Mac cannot decode the codec in hardware")
                    )
                    InspectorRow(
                        label: Text("Size"),
                        value: video.dimensions.map(MediaValueFormat.dimensions))
                    InspectorRow(
                        label: Text("Rotation"),
                        value: MediaValueFormat.rotation(video.rotationDegrees))
                    InspectorRow(
                        label: Text("Bit Rate"), value: video.bitRate.map(MediaValueFormat.bitRate))
                    InspectorRow(
                        label: Text("Frame Rate"),
                        value: video.frameRate.map(MediaValueFormat.frameRate))
                }
            }

            if let colour = inspection.colour {
                InspectorSectionHeader(title: Text("Color", comment: "Inspector section heading"))
                Group {
                    InspectorRow(label: Text("Primaries"), value: colour.primaries)
                    InspectorRow(label: Text("Transfer Function"), value: colour.transferFunction)
                    InspectorRow(label: Text("Matrix"), value: colour.matrix)
                    InspectorRow(
                        label: Text("Range"),
                        value: colour.isFullRange.map {
                            $0
                                ? String(localized: "Full", comment: "Full-range video levels")
                                : String(
                                    localized: "Limited", comment: "Limited-range video levels")
                        }
                    )
                    InspectorRow(
                        label: Text("Bit Depth"),
                        value: colour.bitDepth.map(MediaValueFormat.bitDepth))
                    InspectorRow(
                        label: Text("HDR"),
                        value: colour.isHDR
                            ? String(localized: "Yes", comment: "The video is HDR")
                            : String(localized: "No", comment: "The video is not HDR")
                    )
                }
            }

            if let audio = inspection.audio {
                InspectorSectionHeader(title: Text("Audio", comment: "Inspector section heading"))
                Group {
                    InspectorRow(label: Text("Format"), value: audio.formatCode)
                    InspectorRow(label: Text("Codec"), value: audio.codecName)
                    InspectorRow(label: Text("Channels"), value: audio.channels)
                    InspectorRow(
                        label: Text("Bit Rate"), value: audio.bitRate.map(MediaValueFormat.bitRate))
                    InspectorRow(
                        label: Text("Sample Rate"),
                        value: audio.sampleRate.map(MediaValueFormat.sampleRate))
                    InspectorRow(
                        label: Text("Bit Depth"),
                        value: audio.bitDepth.map(MediaValueFormat.bitDepth))
                }
            }

            if inspection.video == nil && inspection.audio == nil {
                Text(
                    "This file has no video or audio tracks.",
                    comment: "Inspector placeholder for a file with nothing playable in it"
                )
                .foregroundStyle(.secondary)
            }
        }
    }
}
