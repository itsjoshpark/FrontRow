//
//  MediaInspectionLoader.swift
//  Front Row
//
//  Created by Joshua Park on 8/8/26.
//

import AVFoundation
import UniformTypeIdentifiers
import VideoToolbox

/// Reads everything the Inspector shows out of an asset.
///
/// Deliberately thin: it asks AVFoundation for values and hands them to `MediaFormatNames`, which
/// is where the logic worth testing lives. Every property is loaded defensively, since a file only
/// has to be playable - not complete - to reach here.
@MainActor
enum MediaInspectionLoader {

    /// The interesting metadata fields, in the order the File tab shows them.
    private static let metadataKeys: [AVMetadataKey] = [
        .commonKeyTitle,
        .commonKeyArtist,
        .commonKeyAlbumName,
        .commonKeyAuthor,
        .commonKeyPublisher,
        .commonKeyCreationDate,
        .commonKeyDescription,
        .commonKeyCopyrights,
        .commonKeySoftware,
    ]

    static func load(item: AVPlayerItem, url: URL) async -> MediaInspection {
        let asset = item.asset
        let assetTracks = (try? await asset.load(.tracks)) ?? []

        var tracks: [TrackSummary] = []
        var video: VideoSummary?
        var audio: AudioSummary?

        for assetTrack in assetTracks {
            let details = await TrackDetails(track: assetTrack, item: item)

            tracks.append(details.summary)

            if video == nil, details.mediaType == .video {
                video = details.videoSummary
            }
            if audio == nil, details.mediaType == .audio {
                audio = details.audioSummary
            }
        }

        return MediaInspection(
            video: video,
            audio: audio,
            tracks: tracks,
            file: await fileSummary(asset: asset, url: url)
        )
    }

    private static func fileSummary(asset: AVAsset, url: URL) async -> FileSummary {
        var summary = FileSummary(url: url, isLocal: url.isFileURL)

        if let duration = try? await asset.load(.duration), duration.seconds.isFinite {
            summary.duration = duration.seconds
        }

        if url.isFileURL,
            let values = try? url.resourceValues(forKeys: [
                .fileSizeKey, .contentTypeKey, .creationDateKey, .contentModificationDateKey,
            ])
        {
            summary.byteSize = values.fileSize.map(Int64.init)
            summary.containerName = values.contentType?.localizedDescription
            summary.createdAt = values.creationDate
            summary.modifiedAt = values.contentModificationDate
        }

        summary.chapters = await chapters(of: asset)
        summary.metadata = await metadata(of: asset)

        return summary
    }

    private static func chapters(of asset: AVAsset) async -> [ChapterSummary] {
        var groups =
            (try? await asset.loadChapterMetadataGroups(
                bestMatchingPreferredLanguages: Locale.preferredLanguages)) ?? []

        // A chapter track is tagged with its own language, and matching against the viewer's
        // finds nothing when the two differ - the chapters would vanish for want of a
        // translation. Whichever language the file does carry is better than none.
        if groups.isEmpty {
            let locales = (try? await asset.load(.availableChapterLocales)) ?? []
            groups =
                (try? await asset.loadChapterMetadataGroups(
                    bestMatchingPreferredLanguages: locales.map { $0.identifier(.bcp47) })) ?? []
        }

        var chapters: [ChapterSummary] = []
        for (index, group) in groups.enumerated() {
            let titleItem = AVMetadataItem.metadataItems(
                from: group.items, filteredByIdentifier: .commonIdentifierTitle
            ).first
            chapters.append(
                ChapterSummary(
                    id: index,
                    title: try? await titleItem?.load(.stringValue),
                    start: group.timeRange.start.seconds
                ))
        }
        return chapters
    }

    private static func metadata(of asset: AVAsset) async -> [MetadataEntry] {
        let items = (try? await asset.load(.commonMetadata)) ?? []

        var entries: [MetadataEntry] = []
        for key in metadataKeys {
            let matches = AVMetadataItem.metadataItems(
                from: items, withKey: key, keySpace: .common)
            guard let value = try? await matches.first?.load(.stringValue), !value.isEmpty else {
                continue
            }
            entries.append(
                MetadataEntry(id: key.rawValue, label: metadataLabel(for: key), value: value))
        }
        return entries
    }

    private static func metadataLabel(for key: AVMetadataKey) -> String {
        switch key {
        case .commonKeyTitle: String(localized: "Title", comment: "Media metadata field")
        case .commonKeyArtist: String(localized: "Artist", comment: "Media metadata field")
        case .commonKeyAlbumName: String(localized: "Album", comment: "Media metadata field")
        case .commonKeyAuthor: String(localized: "Author", comment: "Media metadata field")
        case .commonKeyPublisher: String(localized: "Publisher", comment: "Media metadata field")
        case .commonKeyCreationDate: String(localized: "Created", comment: "Media metadata field")
        case .commonKeyDescription:
            String(localized: "Description", comment: "Media metadata field")
        case .commonKeyCopyrights: String(localized: "Copyright", comment: "Media metadata field")
        case .commonKeySoftware: String(localized: "Software", comment: "Media metadata field")
        default: key.rawValue
        }
    }
}

/// One track's properties, loaded together so the summaries can be built from a single pass.
@MainActor
private struct TrackDetails {
    let mediaType: AVMediaType
    let format: CMFormatDescription?
    let dataRate: Float
    let frameRate: Float
    let naturalSize: CGSize
    let transform: CGAffineTransform
    let dataLength: Int64
    let characteristics: [AVMediaCharacteristic]
    let isEnabled: Bool
    let isSelected: Bool
    let language: String?
    let title: String?
    let trackID: CMPersistentTrackID

    init(track: AVAssetTrack, item: AVPlayerItem) async {
        // Loaded as a batch, but a batch that throws takes every property with it. A track the
        // asset lists is worth describing from whatever else can be read, so the failure leaves
        // empty fields rather than dropping the track from the list.
        let loaded = try? await track.load(
            .formatDescriptions, .estimatedDataRate, .nominalFrameRate, .naturalSize,
            .preferredTransform, .totalSampleDataLength, .isEnabled)

        self.format = loaded?.0.first
        self.dataRate = loaded?.1 ?? 0
        self.frameRate = loaded?.2 ?? 0
        self.naturalSize = loaded?.3 ?? .zero
        self.transform = loaded?.4 ?? .identity
        self.dataLength = loaded?.5 ?? 0
        self.isEnabled = loaded?.6 ?? false
        self.characteristics = (try? await track.load(.mediaCharacteristics)) ?? []
        self.mediaType = track.mediaType
        self.trackID = track.trackID

        // The player only carries tracks for the current item, and only those it decided to play.
        self.isSelected =
            item.tracks.first { $0.assetTrack?.trackID == track.trackID }?.isEnabled ?? false

        let tag = try? await track.load(.extendedLanguageTag)
        let code = try? await track.load(.languageCode)
        self.language = Self.languageName(tag: tag ?? code)

        let metadata = (try? await track.load(.commonMetadata)) ?? []
        let titleItem = AVMetadataItem.metadataItems(
            from: metadata, filteredByIdentifier: .commonIdentifierTitle
        ).first
        self.title = try? await titleItem?.load(.stringValue)
    }

    /// Resolves a language tag to its name in the viewer's language. `und` is what an MP4 writes
    /// when the track was never tagged, so it counts as no language at all.
    private static func languageName(tag: String?) -> String? {
        guard let tag, !tag.isEmpty, tag != "und" else { return nil }
        return Locale.current.localizedString(forIdentifier: tag) ?? tag
    }

    private var subType: FourCharCode? { format?.mediaSubType.rawValue }

    private var dimensions: CGSize? {
        guard mediaType == .video else { return nil }
        guard let format else { return naturalSize == .zero ? nil : naturalSize }
        let dimensions = format.dimensions
        return CGSize(width: Int(dimensions.width), height: Int(dimensions.height))
    }

    private var bitRate: Double? { dataRate > 0 ? Double(dataRate) : nil }

    private var audioFormat: AudioStreamBasicDescription? {
        guard mediaType == .audio else { return nil }
        return format?.audioStreamBasicDescription
    }

    private var channels: String? {
        guard let audioFormat else { return nil }
        return MediaFormatNames.channelLayoutName(
            for: format?.audioChannelLayout, channelCount: audioFormat.mChannelsPerFrame)
    }

    private var codecName: String? {
        switch mediaType {
        case .video: subType.map(MediaFormatNames.videoCodecName(for:))
        case .audio: audioFormat.map { MediaFormatNames.audioCodecName(for: $0.mFormatID) }
        default: nil
        }
    }

    /// A format-description extension read as a string, which is how the colour constants and the
    /// encoder name are stored.
    private func stringExtension(_ key: CMFormatDescription.Extensions.Key) -> String? {
        format?.extensions[key]?.propertyListRepresentation as? String
    }

    private func numberExtension(_ key: CMFormatDescription.Extensions.Key) -> Int? {
        (format?.extensions[key]?.propertyListRepresentation as? NSNumber)?.intValue
    }

    /// CoreMedia states the depth for HEVC but leaves it out for H.264, where the answer is always
    /// 8 - AVFoundation won't play a deeper H.264 stream at all.
    private var videoBitDepth: Int? {
        if let stated = numberExtension(.bitsPerComponent) { return stated }
        return subType == kCMVideoCodecType_H264 ? 8 : nil
    }

    var summary: TrackSummary {
        TrackSummary(
            id: trackID,
            kind: kind,
            formatCode: subType.map(MediaFormatNames.fourCC),
            codecName: codecName,
            isEnabled: isEnabled,
            isSelected: isSelected,
            isMainProgram: characteristics.contains(.isMainProgramContent),
            isForced: characteristics.contains(.containsOnlyForcedSubtitles),
            title: title,
            languageName: language,
            dataSize: dataLength > 0 ? dataLength : nil,
            dimensions: dimensions,
            frameRate: mediaType == .video && frameRate > 0 ? Double(frameRate) : nil,
            channels: channels,
            sampleRate: audioFormat.map(\.mSampleRate),
            bitRate: bitRate
        )
    }

    private var kind: TrackKind {
        switch mediaType {
        case .video: .video
        case .audio: .audio
        case .subtitle: .subtitle
        case .text: .text
        case .closedCaption: .closedCaption
        default: .other(mediaType.rawValue)
        }
    }

    var videoSummary: VideoSummary? {
        guard let subType else { return nil }
        return VideoSummary(
            formatCode: MediaFormatNames.fourCC(subType),
            codecName: MediaFormatNames.videoCodecName(for: subType),
            encoder: stringExtension(.formatName),
            isHardwareDecodeSupported: VTIsHardwareDecodeSupported(subType),
            dimensions: dimensions,
            rotationDegrees: MediaFormatNames.rotationDegrees(for: transform),
            bitRate: bitRate,
            frameRate: frameRate > 0 ? Double(frameRate) : nil,
            bitDepth: videoBitDepth,
            colorPrimaries: stringExtension(.colorPrimaries).map(MediaFormatNames.colourName(for:)),
            isFullRange: numberExtension(.fullRangeVideo).map { $0 != 0 },
            isHDR: characteristics.contains(.containsHDRVideo),
            hdrFormatName: stringExtension(.transferFunction)
                .flatMap(MediaFormatNames.hdrFormatName(forTransferFunction:))
        )
    }

    var audioSummary: AudioSummary? {
        guard let subType, let audioFormat else { return nil }
        return AudioSummary(
            formatCode: MediaFormatNames.fourCC(subType),
            codecName: MediaFormatNames.audioCodecName(for: audioFormat.mFormatID),
            channels: channels ?? "",
            bitRate: bitRate,
            sampleRate: audioFormat.mSampleRate > 0 ? audioFormat.mSampleRate : nil,
            bitDepth: audioFormat.mBitsPerChannel > 0 ? Int(audioFormat.mBitsPerChannel) : nil
        )
    }
}
