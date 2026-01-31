//
//  NowPlayable+RemoteCommands.swift
//  Front Row
//
//  Created by Joshua Park on 5/29/25.
//

import MediaPlayer

extension NowPlayable {
    @MainActor func setupRemoteCommandHandlers(playEngine: PlayEngine) {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { _ in
            playEngine.play()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { _ in
            playEngine.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            playEngine.playPause()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task {
                await playEngine.goToTime(event.positionTime)
            }
            return .success
        }

        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [
            NSNumber(value: playEngine.skipInterval)
        ]
        commandCenter.skipForwardCommand.addTarget { _ in
            Task {
                await playEngine.goForwards()
            }
            return .success
        }

        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [
            NSNumber(value: playEngine.skipInterval)
        ]
        commandCenter.skipBackwardCommand.addTarget { _ in
            Task {
                await playEngine.goBackwards()
            }
            return .success
        }
    }

    func removeRemoteCommandHandlers() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
    }
}
