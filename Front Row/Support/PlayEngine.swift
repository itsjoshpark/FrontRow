//
//  PlayEngine.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import AVKit
import Combine
import SwiftUI

@MainActor
@Observable public final class PlayEngine {

    static let shared = PlayEngine()

    static let supportedFileTypes: [UTType] = [
        .mp3,
        .mpeg2TransportStream,
        .mpeg4Audio,
        .mpeg4Movie,
        .quickTimeMovie,
        .wav,
    ]

    static let skipIntervals: [Int] = [
        5,
        10,
        15,
        30,
    ]

    // Resume thresholds (seconds): a saved position is only resumed if it's past
    // `resumeMinimumPosition` and more than `resumeEndBuffer` from the end.
    private static let resumeMinimumPosition: TimeInterval = 3
    private static let resumeEndBuffer: TimeInterval = 5

    /// How often (in seconds of playback) the current position is saved while playing.
    private static let periodicPositionSaveInterval: TimeInterval = 5

    private var asset: AVAsset?

    private var lastPeriodicPositionSaveTime: TimeInterval = 0

    private(set) var player = AVPlayer()

    private(set) var isLoaded = false

    private(set) var timeControlStatus: AVPlayer.TimeControlStatus = .paused

    private(set) var isLocalFile = false

    private(set) var fileURL: URL?

    private var _currentTime: TimeInterval = 0.0

    var currentTime: Double {
        get {
            access(keyPath: \.currentTime)
            return _currentTime
        }
        set {
            withMutation(keyPath: \.currentTime) {
                let time = CMTimeMakeWithSeconds(newValue, preferredTimescale: 1)
                player.seek(to: time)
                updateNowPlayingInfo()
            }
        }
    }

    private(set) var duration: TimeInterval = 0.0

    private(set) var timeRemaining: TimeInterval = 0.0

    private var wasPausedBeforeSeeking = false

    var playbackSpeed: Float {
        get {
            access(keyPath: \.playbackSpeed)
            return player.defaultRate
        }
        set {
            withMutation(keyPath: \.playbackSpeed) {
                if Float.isApproxEqual(lhs: newValue, rhs: 1.0) {
                    player.rate = 1.0
                    player.defaultRate = 1.0
                    return
                }

                if newValue > player.defaultRate {
                    let newSpeed = min(newValue, 2.0)
                    player.rate = newSpeed
                    player.defaultRate = newSpeed
                } else if newValue < player.defaultRate {
                    let newSpeed = max(newValue, 0.05)
                    player.rate = newSpeed
                    player.defaultRate = newSpeed
                } else {
                    player.rate = newValue
                    player.defaultRate = newValue
                }
            }
        }
    }

    @ObservationIgnored @AppStorage("SkipInterval") private var _skipInterval: Int = 5

    var skipInterval: Int {
        get {
            access(keyPath: \.skipInterval)
            return _skipInterval
        }
        set {
            withMutation(keyPath: \.skipInterval) {
                _skipInterval = newValue
            }
        }
    }

    private var _isMuted = false

    var isMuted: Bool {
        get {
            access(keyPath: \.isMuted)
            return _isMuted
        }
        set {
            withMutation(keyPath: \.isMuted) {
                _isMuted = newValue
                player.isMuted = newValue
            }
        }
    }

    private(set) var subtitleGroup: AVMediaSelectionGroup?

    var subtitle: AVMediaSelectionOption? {
        didSet {
            guard let subtitleGroup else { return }
            selectTrack(subtitle, in: subtitleGroup)
        }
    }

    private(set) var audioGroup: AVMediaSelectionGroup?

    var audioTrack: AVMediaSelectionOption? {
        didSet {
            guard let audioGroup else { return }
            selectTrack(audioTrack, in: audioGroup)
        }
    }

    private var videoSize = CGSize.zero

    private var subs = Set<AnyCancellable>()

    private var currentItemSubs = Set<AnyCancellable>()

    private var timeObserver: Any?

    /// The URL this instance currently holds security-scoped access to, if any. Must be stopped
    /// before accessing a different file.
    private var accessingSecurityScopedURL: URL?

    private init() {
        NowPlayable.shared.sessionStart()
        NowPlayable.shared.setupRemoteCommandHandlers(playEngine: self)

        player.preventsDisplaySleepDuringVideoPlayback = true
        player.appliesMediaSelectionCriteriaAutomatically = false

        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                self.timeControlStatus = status
                self.updateNowPlayingInfo()
                // Skip when paused because playback reached the end - that position is cleared by
                // the play-to-end observer, so persisting here would just leave an orphan entry.
                if status == .paused, !self.isPlaybackAtEnd {
                    self.persistCurrentPlaybackPosition()
                }
            }
            .store(in: &subs)

        player.publisher(for: \.rate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rate in
                self?.updateNowPlayingInfo()
            }
            .store(in: &subs)

        player.publisher(for: \.isMuted)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isMuted in
                self?._isMuted = isMuted
            }
            .store(in: &subs)

        addPeriodicTimeObserver()
    }

    /// Attempts to open file at url. If its not playable, returns false.
    /// - Parameter url: A URL to a local, remote, or HTTP Live Streaming media resource.
    /// - Returns: A Boolean value that indicates whether an asset contains playable content.
    @discardableResult func openFile(url originalURL: URL) async -> Bool {
        persistCurrentPlaybackPosition()
        lastPeriodicPositionSaveTime = 0

        let url = resolveAccessibleURL(originalURL)

        if asset != nil {
            asset!.cancelLoading()
        }
        let newAsset = AVURLAsset(url: url)
        asset = newAsset

        var mediaDuration: TimeInterval = .nan
        do {
            let isPlayable = try await newAsset.load(.isPlayable)
            guard isPlayable else { return false }

            self.subtitleGroup = try? await newAsset.loadMediaSelectionGroup(for: .legible)
            self.audioGroup = try? await newAsset.loadMediaSelectionGroup(for: .audible)
            if let loadedDuration = try? await newAsset.load(.duration) {
                mediaDuration = loadedDuration.seconds
            }
        } catch {
            return false
        }

        let playerItem = AVPlayerItem(asset: newAsset)
        installObservers(on: playerItem, url: url)

        player.replaceCurrentItem(with: playerItem)

        await resumeIfNeeded(url: url, duration: mediaDuration)

        player.play()

        self.subtitle = subtitleGroup?.options.first
        self.audioTrack = audioGroup?.options.first

        return true
    }

    /// Resolves the URL to open into one this process can actually read.
    ///
    /// Reopening a previously selected file (recents/resume) requires resolving its
    /// security-scoped bookmark, since the access granted by the open panel/drag-and-drop doesn't
    /// survive relaunch. A first-time URL already has ambient access, so it's used as-is.
    private func resolveAccessibleURL(_ originalURL: URL) -> URL {
        accessingSecurityScopedURL?.stopAccessingSecurityScopedResource()
        accessingSecurityScopedURL = nil

        guard
            let accessibleURL = RecentDocumentsStore.shared.startAccessingRecentDocument(
                originalURL)
        else { return originalURL }

        accessingSecurityScopedURL = accessibleURL
        return accessibleURL
    }

    private func installObservers(on playerItem: AVPlayerItem, url: URL) {
        for sub in currentItemSubs { sub.cancel() }
        currentItemSubs.removeAll()

        playerItem.publisher(for: \.status)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .readyToPlay:
                    self.isLoaded = true
                    self.isLocalFile = FileManager.default.fileExists(
                        atPath: url.path(percentEncoded: false))
                    self.fileURL = url
                    NowPlayable.shared.setNowPlayingMetadata(
                        NowPlayableStaticMetadata(
                            assetURL: url,
                            mediaType: self.videoSize == .zero ? .audio : .video,
                            title: url.lastPathComponent
                        ))
                    self.updateNowPlayingInfo()
                case .failed:
                    self.isLoaded = false
                    self.isLocalFile = false
                    self.fileURL = nil
                    NowPlayable.shared.sessionEnd()
                default:
                    break
                }
            }
            .store(in: &currentItemSubs)

        playerItem.publisher(for: \.presentationSize)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] size in
                guard let self else { return }
                self.videoSize = size
                self.fitToVideoSize(skipResize: WindowController.shared.isFullscreen)
            }
            .store(in: &currentItemSubs)

        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                PlaybackPositionStore.shared.clearPosition(for: url)
            }
            .store(in: &currentItemSubs)
    }

    /// Seeks to a previously saved position if one exists and is worth resuming from (far enough
    /// in, but not effectively finished).
    private func resumeIfNeeded(url: URL, duration: TimeInterval) async {
        guard let saved = PlaybackPositionStore.shared.position(for: url),
            !duration.isNaN,
            saved > Self.resumeMinimumPosition,
            saved < duration - Self.resumeEndBuffer
        else { return }

        await player.seek(to: CMTimeMakeWithSeconds(saved, preferredTimescale: 1))
    }

    /// Whether playback is effectively at the end, using the same buffer as resume so a position
    /// this close to the end wouldn't be resumed from anyway.
    private var isPlaybackAtEnd: Bool {
        guard duration > 0 else { return false }
        return _currentTime >= duration - Self.resumeEndBuffer
    }

    /// Saves the current playback position immediately, as a safety net on pause, before switching
    /// files, and on termination. Only files in the recent documents list are tracked.
    func persistCurrentPlaybackPosition() {
        guard let fileURL, RecentDocumentsStore.shared.recentURLs.contains(fileURL) else { return }
        PlaybackPositionStore.shared.setPosition(_currentTime, for: fileURL)
    }

    func cancelLoading() {
        guard let asset else { return }

        asset.cancelLoading()
    }

    func play() {
        guard isLoaded else { return }

        player.play()
    }

    func pause() {
        guard isLoaded else { return }

        player.pause()
    }

    func playPause() {
        guard isLoaded else { return }

        if timeControlStatus == .playing {
            pause()
        } else {
            play()
        }
    }

    func goForwards() async {
        guard isLoaded else { return }

        /// If needed pause playback to improve seek performance
        pausePlaybackIfNeeded()

        let time = CMTimeAdd(
            player.currentTime(),
            CMTimeMakeWithSeconds(Double(skipInterval), preferredTimescale: 1)
        )
        await player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)

        resumePlaybackIfNeeded()
    }

    func goBackwards() async {
        guard isLoaded else { return }

        /// If needed pause playback to improve seek performance
        pausePlaybackIfNeeded()

        let time = CMTimeSubtract(
            player.currentTime(),
            CMTimeMakeWithSeconds(Double(skipInterval), preferredTimescale: 1)
        )
        await player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)

        resumePlaybackIfNeeded()
    }

    func goToTime(_ timecode: Double) async {
        guard isLoaded else { return }

        let time = CMTimeMakeWithSeconds(timecode, preferredTimescale: 1)
        await player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        updateNowPlayingInfo()
    }

    func goToTime(_ timecode: String) async {
        guard isLoaded, let item = player.currentItem else { return }

        let split = Array(timecode.split(separator: ":").reversed())

        let _hour: Int? = split.count > 2 ? Int(split[2]) : nil
        let _minute: Int? = split.count > 1 ? Int(split[1]) : nil
        let _second: Double? = !split.isEmpty ? Double(split[0]) : nil

        if _hour == nil && _minute == nil && _second == nil {
            return
        }

        let hour = _hour ?? 0
        let minute = _minute ?? 0
        let second = _second ?? 0.0
        let time = CMTimeMakeWithSeconds(
            Double(hour * 3600 + minute * 60) + second, preferredTimescale: 1)

        let validRange = CMTimeRange(start: .zero, end: item.duration)
        guard validRange.containsTime(time) else { return }
        await player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        updateNowPlayingInfo()
    }

    @MainActor
    func frameStep(_ byCount: Int) {
        guard isLoaded, let item = player.currentItem else { return }

        item.step(byCount: byCount)
    }

    func fitToVideoSize(skipResize: Bool = false) {
        guard let window = WindowController.shared.mainWindow else { return }
        guard videoSize != CGSize.zero else {
            /// reset aspect ratio setting
            window.resizeIncrements = NSMakeSize(1.0, 1.0)
            return
        }

        let screenFrame = (window.screen ?? NSScreen.main!).visibleFrame
        let newFrame: NSRect

        if videoSize.width < screenFrame.width && videoSize.height < screenFrame.height {
            let newOrigin = CGPoint(
                x: screenFrame.origin.x + (screenFrame.width - videoSize.width) / 2,
                y: screenFrame.origin.y + (screenFrame.height - videoSize.height) / 2
            )
            newFrame = NSRect(origin: newOrigin, size: videoSize)
        } else {
            let newSize = videoSize.shrink(toSize: screenFrame.size)
            let newOrigin = CGPoint(
                x: screenFrame.origin.x + (screenFrame.width - newSize.width) / 2,
                y: screenFrame.origin.y + (screenFrame.height - newSize.height) / 2
            )
            newFrame = NSRect(origin: newOrigin, size: newSize)
        }
        if !skipResize {
            window.setFrame(newFrame, display: true, animate: true)
        }
        window.aspectRatio = videoSize
    }

    private func pausePlaybackIfNeeded() {
        guard player.rate != 0 else { return }
        wasPausedBeforeSeeking = true
        player.rate = 0
    }

    private func resumePlaybackIfNeeded() {
        guard wasPausedBeforeSeeking else { return }
        player.rate = player.defaultRate
        wasPausedBeforeSeeking = false
    }

    private func selectTrack(_ option: AVMediaSelectionOption?, in group: AVMediaSelectionGroup) {
        guard let item = player.currentItem else { return }
        item.select(option, in: group)
    }

    private func addPeriodicTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                self._currentTime = time.seconds

                guard let duration = self.player.currentItem?.duration.seconds else { return }
                guard !duration.isNaN && !duration.isInfinite else { return }
                self.duration = duration
                self.timeRemaining = duration - self._currentTime

                if time.seconds - self.lastPeriodicPositionSaveTime
                    >= Self.periodicPositionSaveInterval
                {
                    self.lastPeriodicPositionSaveTime = time.seconds
                    self.persistCurrentPlaybackPosition()
                }
            }
        }
    }

    private func removePeriodicTimeObserver() {
        guard let timeObserver else { return }
        player.removeTimeObserver(timeObserver)
        self.timeObserver = nil
    }

    private func updateNowPlayingInfo() {
        NowPlayable.shared.setNowPlayingPlaybackInfo(
            playing: timeControlStatus == .playing,
            NowPlayableDynamicMetadata(
                rate: player.rate,
                position: Float(currentTime),
                duration: Float(duration)
            )
        )
    }
}
