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

/// The real `MountedVolumesProviding`.
///
/// Read on demand rather than cached, since the only thing that asks is a file that just failed to
/// open - rare enough that keeping a mount/unmount-observed copy in sync would cost more than it
/// saves, and a fresh answer is always the correct one.
@MainActor
final class MountedVolumes: MountedVolumesProviding {

    static let shared = MountedVolumes()

    private init() {}

    var mountedVolumeURLs: [URL] {
        FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [])?
            .map(\.standardizedFileURL) ?? []
    }
}
