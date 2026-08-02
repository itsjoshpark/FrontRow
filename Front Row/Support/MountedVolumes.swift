//
//  MountedVolumes.swift
//  Front Row
//
//  Created by Joshua Park on 8/2/26.
//

import AppKit
import SwiftUI

/// Wraps the set of currently mounted volumes so a recent document on a disconnected drive can be
/// told apart from one that's genuinely gone, and so tests can simulate ejecting a drive.
@MainActor
protocol MountedVolumesProviding {
    var mountedVolumeURLs: [URL] { get }
}

/// The real `MountedVolumesProviding`, kept current by mount/unmount notifications.
///
/// `@Observable` so the recent files list redraws by itself when a drive is connected or ejected.
@MainActor
@Observable
final class MountedVolumes: MountedVolumesProviding {

    static let shared = MountedVolumes()

    private(set) var mountedVolumeURLs: [URL] = []

    private var observationTasks: [Task<Void, Never>] = []

    private init() {
        refresh()

        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
            observationTasks.append(
                Task { [weak self] in
                    for await _ in center.notifications(named: name) {
                        self?.refresh()
                    }
                })
        }
    }

    private func refresh() {
        mountedVolumeURLs =
            FileManager.default.mountedVolumeURLs(
                includingResourceValuesForKeys: nil, options: []
            )?
            .map(\.standardizedFileURL) ?? []
    }
}
