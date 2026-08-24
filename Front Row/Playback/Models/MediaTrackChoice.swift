//
//  MediaTrackChoice.swift
//  Front Row
//
//  Created by Joshua Park on 8/24/26.
//

import AVFoundation

/// One entry in the Audio Track or Subtitle menu.
///
/// Containers describe their alternate tracks two ways, so the menus are built from two. A file
/// that groups its tracks gets a media selection group, which AVFoundation switches between. A
/// file that groups nothing has tracks and no more, and the choice is applied by enabling one of
/// the player item's tracks.
struct MediaTrackChoice: Identifiable, Hashable {

    /// How picking this entry is applied to the player item.
    enum Selection: Hashable {
        case option(AVMediaSelectionOption)
        case track(CMPersistentTrackID)
    }

    let id: String
    let name: String
    let selection: Selection
}

extension MediaTrackChoice {

    /// The name to show for one track.
    ///
    /// - Parameters:
    ///   - title: The track's own title. An MP4 track title and an HLS rendition's `NAME` both
    ///     arrive here, and either is the best name there is.
    ///   - languageTag: The track's language.
    ///   - describedName: What AVFoundation calls the option, which qualifies a language with
    ///     "Forced" or "SDH". Nil for a plain asset track, which carries no such name.
    ///   - index: The track's place among its own kind, counting from one.
    static func name(
        title: String?,
        languageTag: String?,
        describedName: String?,
        index: Int
    ) -> String {
        let language = MediaLanguageName.name(forTag: languageTag)

        if let title, !title.isEmpty {
            guard let language else { return title }
            return String(
                localized: "\(title) (\(language))",
                comment: "A media track named by its title, qualified by its language"
            )
        }

        // An untagged option is named after `und` itself - "Unknown language" - which says no more
        // than the number does, and reads like a language the file claims to be in.
        if !MediaLanguageName.isUndetermined(languageTag), let describedName, !describedName.isEmpty
        {
            return describedName
        }

        if let language { return language }

        return String(
            localized: "Track \(index)",
            comment: "A media track that carries no name or language of its own"
        )
    }

    /// The choices to offer for one kind of track.
    ///
    /// A media selection group is used wherever the asset has one - it is what HTTP Live Streaming
    /// and well-tagged files describe themselves with. Only when there is none do the asset's own
    /// tracks stand in.
    @MainActor
    static func choices(
        in group: AVMediaSelectionGroup?,
        of asset: AVAsset,
        mediaTypes: [AVMediaType]
    ) async -> [MediaTrackChoice] {
        if let group {
            return await choices(in: group)
        }

        var tracks: [AVAssetTrack] = []
        for mediaType in mediaTypes {
            tracks += (try? await asset.loadTracks(withMediaType: mediaType)) ?? []
        }
        return await choices(from: tracks)
    }

    @MainActor
    private static func choices(in group: AVMediaSelectionGroup) async -> [MediaTrackChoice] {
        var choices: [MediaTrackChoice] = []
        for option in group.selectableOptions {
            let title = try? await AVMetadataItem.metadataItems(
                from: option.commonMetadata, filteredByIdentifier: .commonIdentifierTitle
            ).first?.load(.stringValue)

            choices.append(
                MediaTrackChoice(
                    id: option.stableID,
                    name: name(
                        title: title,
                        languageTag: option.extendedLanguageTag,
                        describedName: option.displayName,
                        index: choices.count + 1
                    ),
                    selection: .option(option)
                ))
        }
        return choices
    }

    @MainActor
    private static func choices(from tracks: [AVAssetTrack]) async -> [MediaTrackChoice] {
        var choices: [MediaTrackChoice] = []
        for track in tracks {
            let characteristics = (try? await track.load(.mediaCharacteristics)) ?? []
            guard !characteristics.contains(.containsOnlyForcedSubtitles) else { continue }

            let metadata = (try? await track.load(.commonMetadata)) ?? []
            let title = try? await AVMetadataItem.metadataItems(
                from: metadata, filteredByIdentifier: .commonIdentifierTitle
            ).first?.load(.stringValue)

            let tag = try? await track.load(.extendedLanguageTag)
            let code = try? await track.load(.languageCode)

            choices.append(
                MediaTrackChoice(
                    id: "track-\(track.trackID)",
                    name: name(
                        title: title,
                        languageTag: tag ?? code,
                        describedName: nil,
                        index: choices.count + 1
                    ),
                    selection: .track(track.trackID)
                ))
        }
        return choices
    }
}
