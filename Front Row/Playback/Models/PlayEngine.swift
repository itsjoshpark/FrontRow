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
@Observable final class PlayEngine {

    static let shared = PlayEngine()

    /// Containers AVFoundation opens directly.
    private static let supportedFileTypes: [UTType] = [
        .mp3,
        .mpeg2TransportStream,
        .mpeg4Audio,
        .mpeg4Movie,
        .quickTimeMovie,
        .wav,
    ]

    /// Containers Front Row can't play, but can convert into one it can.
    static let convertibleFileExtensions: Set<String> = ["mkv"]

    /// The content types those extensions resolve to on this Mac.
    ///
    /// Looked up rather than named outright: Matroska has no system-declared type, so what `mkv`
    /// maps to depends on what else is installed. Asking LaunchServices is what keeps the Open
    /// panel and drag and drop agreeing with the Finder about the same file.
    private static let convertibleFileTypes: [UTType] = convertibleFileExtensions.compactMap {
        UTType(filenameExtension: $0)
    }

    /// Everything the Open panel and drag and drop accept.
    static let openableFileTypes: [UTType] = supportedFileTypes + convertibleFileTypes

    /// Whether opening this file means converting it first.
    static func isConvertible(_ url: URL) -> Bool {
        url.isFileURL && convertibleFileExtensions.contains(url.pathExtension.lowercased())
    }

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
                let speed = PlaybackSpeed.clamped(newValue)
                player.rate = speed
                player.defaultRate = speed
            }
        }
    }

    @ObservationIgnored @AppStorage("SkipInterval") private var _skipInterval: SkipInterval = .five

    var skipInterval: SkipInterval {
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

    /// The size the current item presents at, or `.zero` when there's no video to it. Read by the
    /// player window to decide its shape, which is why it outlives the moment it's published.
    private(set) var videoSize = CGSize.zero

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
                if status == .paused {
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

    /// Loads the media at `url` into the player and starts it.
    ///
    /// The engine's half only. Opening a file with a playback window is done through
    /// `openFile(url:)`.
    /// - Parameter url: A URL to a local, remote, or HTTP Live Streaming media resource.
    /// - Returns: Whether the asset opened, and if not, which kind of failure it was.
    @discardableResult func loadAndPlay(url originalURL: URL) async -> FileOpenResult {
        persistCurrentPlaybackPosition()

        lastPeriodicPositionSaveTime = 0

        let url = resolveAccessibleURL(originalURL)

        asset?.cancelLoading()

        let newAsset = AVURLAsset(url: url)
        asset = newAsset

        var mediaDuration: TimeInterval = .nan
        do {
            let isPlayable = try await newAsset.load(.isPlayable)
            guard isPlayable else { return .unplayable }

            self.subtitleGroup = try? await newAsset.loadMediaSelectionGroup(for: .legible)
            self.audioGroup = try? await newAsset.loadMediaSelectionGroup(for: .audible)
            if let loadedDuration = try? await newAsset.load(.duration) {
                mediaDuration = loadedDuration.seconds
            }
        } catch {
            return .unreadable
        }

        // Recorded here rather than waiting for the item to become ready, so callers can ask what
        // actually opened - which is where a file renamed outside the app now lives.
        fileURL = url

        let playerItem = AVPlayerItem(asset: newAsset)
        installObservers(on: playerItem, url: url)

        // Nothing is known about the new item's size yet, and keeping the old one's would leave
        // the window shaped to the file that just went away.
        videoSize = .zero

        player.replaceCurrentItem(with: playerItem)

        await resumeIfNeeded(url: url, duration: mediaDuration)

        player.play()

        self.subtitle = subtitleGroup?.options.first
        self.audioTrack = audioGroup?.options.first

        return .opened
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
                self?.videoSize = size
            }
            .store(in: &currentItemSubs)

        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                RecentDocumentsStore.shared.clearPosition(for: url)
            }
            .store(in: &currentItemSubs)
    }

    /// Seeks to a previously saved position if one exists and is worth resuming from (far enough
    /// in, but not effectively finished).
    private func resumeIfNeeded(url: URL, duration: TimeInterval) async {
        let saved = RecentDocumentsStore.shared.position(for: url)
        guard let target = ResumePolicy.resumePosition(saved: saved, duration: duration) else {
            return
        }

        await player.seek(to: CMTimeMakeWithSeconds(target, preferredTimescale: 1))
    }

    /// Whether playback is effectively at the end, using the same buffer as resume so a position
    /// this close to the end wouldn't be resumed from anyway.
    private var isPlaybackAtEnd: Bool {
        ResumePolicy.isAtEnd(currentTime: _currentTime, duration: duration)
    }

    /// Saves the current playback position immediately, as a safety net on pause, before switching
    /// files, and on termination. Only files in the recent documents list are tracked, and a
    /// position this close to the end is skipped - it was just cleared by the play-to-end
    /// observer, so persisting here would just leave an orphan entry.
    func persistCurrentPlaybackPosition() {
        guard let fileURL, !isPlaybackAtEnd else { return }
        RecentDocumentsStore.shared.setPosition(_currentTime, for: fileURL)
    }

    func cancelLoading() {
        guard let asset else { return }

        asset.cancelLoading()
    }

    /// Unloads the file, leaving the engine as it was before anything was opened.
    ///
    /// Closing the player window usually takes the app with it, so the state that outlives the
    /// window only shows when another window keeps the app running. What's left behind would
    /// otherwise still answer for a file with nowhere to play it.
    func closeFile() {
        persistCurrentPlaybackPosition()
        lastPeriodicPositionSaveTime = 0

        for sub in currentItemSubs { sub.cancel() }
        currentItemSubs.removeAll()

        player.pause()
        player.replaceCurrentItem(with: nil)

        asset?.cancelLoading()
        asset = nil

        // Cleared before the selections, whose observers go no further once the group is gone.
        subtitleGroup = nil
        audioGroup = nil
        subtitle = nil
        audioTrack = nil

        isLoaded = false
        isLocalFile = false
        fileURL = nil

        _currentTime = 0
        duration = 0
        timeRemaining = 0
        videoSize = .zero

        accessingSecurityScopedURL?.stopAccessingSecurityScopedResource()
        accessingSecurityScopedURL = nil

        NowPlayable.shared.sessionEnd()
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
            CMTimeMakeWithSeconds(skipInterval.seconds, preferredTimescale: 1)
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
            CMTimeMakeWithSeconds(skipInterval.seconds, preferredTimescale: 1)
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
        guard isLoaded, let item = player.currentItem,
            let seconds = Timecode.parse(timecode)
        else { return }

        let time = CMTimeMakeWithSeconds(seconds, preferredTimescale: 1)

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
