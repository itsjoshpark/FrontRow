//
//  RemuxAlert.swift
//  Front Row
//
//  Created by Joshua Park on 8/15/26.
//

import Foundation

/// A conversion that's been worked out and is waiting on the user.
struct RemuxOffer {
    var url: URL
    var plan: RemuxPlan
    var duration: TimeInterval?
    var tools: FFmpegTools
    var scene: AlertScene
}

/// Why a file won't be converted.
struct RemuxProblem {
    enum Reason: Equatable {
        /// ffmpeg, ffprobe, or both aren't installed. Which button to offer depends on whether the
        /// package manager that would install them is there.
        case toolsMissing(hasHomebrew: Bool)
        /// A stream in the file can't be decoded, so the container isn't the problem.
        case unsupported
        /// ffprobe couldn't make sense of the file.
        case probeFailed
        /// ffprobe was still reading when its deadline passed. The file may be perfectly good and
        /// merely somewhere slow, so this must not say it is damaged.
        case checkTimedOut
    }

    var url: URL
    var reason: Reason
    var scene: AlertScene
}

/// A finished conversion, with the original still sitting next to it.
struct RemuxCleanup {
    var originalURL: URL
    var convertedURL: URL
    var scene: AlertScene
}

/// Whichever question a conversion is putting to the user.
///
/// One value rather than three, because a view gets one alert. Stacking a modifier per stage leaves
/// them contending for the same presentation slot, and one of them silently loses.
enum RemuxAlert {
    case offer(RemuxOffer)
    case cleanup(RemuxCleanup)
    case problem(RemuxProblem)

    /// The scene that raised this, and so the only one that presents it.
    var scene: AlertScene {
        switch self {
        case .offer(let offer): offer.scene
        case .cleanup(let cleanup): cleanup.scene
        case .problem(let problem): problem.scene
        }
    }
}
