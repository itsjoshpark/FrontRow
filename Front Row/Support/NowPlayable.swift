//
//  NowPlayable.swift
//  Front Row
//
//  Created by Joshua Park on 5/26/25.
//

import MediaPlayer

struct NowPlayableStaticMetadata {
    // MPNowPlayingInfoPropertyAssetURL
    let assetURL: URL

    // MPNowPlayingInfoPropertyMediaType
    let mediaType: MPNowPlayingInfoMediaType

    // MPMediaItemPropertyTitle
    let title: String
}

struct NowPlayableDynamicMetadata {
    // MPNowPlayingInfoPropertyPlaybackRate
    let rate: Float

    // MPNowPlayingInfoPropertyElapsedPlaybackTime
    let position: Float

    // MPMediaItemPropertyPlaybackDuration
    let duration: Float
}

@MainActor
final class NowPlayable {

    static let shared = NowPlayable()

    func sessionStart() {
        MPNowPlayingInfoCenter.default().playbackState = .paused
    }

    func sessionEnd() {
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    func setNowPlayingMetadata(_ metadata: NowPlayableStaticMetadata) {
        let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPNowPlayingInfoPropertyAssetURL] = metadata.assetURL
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = metadata.mediaType.rawValue
        nowPlayingInfo[MPMediaItemPropertyTitle] = metadata.title
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }

    func setNowPlayingPlaybackInfo(playing isPlaying: Bool, _ metadata: NowPlayableDynamicMetadata)
    {
        let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        var nowPlayingInfo = nowPlayingInfoCenter.nowPlayingInfo ?? [String: Any]()
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = metadata.rate
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = metadata.position
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = metadata.duration
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
        nowPlayingInfoCenter.playbackState = isPlaying ? .playing : .paused
    }
}
