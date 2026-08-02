//
//  FakeMountedVolumesProvider.swift
//  Front Row Tests
//

import Foundation

@testable import Front_Row

/// Lets a test connect and eject volumes without touching real hardware.
///
/// Starts with only the boot volume mounted, which is what an entry with no recorded volume is
/// implicitly compared against.
final class FakeMountedVolumesProvider: MountedVolumesProviding {

    var mountedVolumeURLs: [URL] = [URL(filePath: "/")]

    func mount(_ volumeURL: URL) {
        guard !mountedVolumeURLs.contains(volumeURL) else { return }
        mountedVolumeURLs.append(volumeURL)
    }

    func unmount(_ volumeURL: URL) {
        mountedVolumeURLs.removeAll { $0 == volumeURL }
    }
}
