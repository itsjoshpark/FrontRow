//
//  UnopenableRecentFileAlertTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

struct UnopenableRecentFileAlertTests {

    private let file = URL(fileURLWithPath: "/Volumes/Media/movie.mov")

    /// A file that wouldn't open because its drive is unplugged must not be diagnosed as missing,
    /// and dismissing must leave the entry alone - the drive is coming back.
    @Test
    func aDisconnectedVolumeIsDiagnosedAndDismissesWithoutRemoving() {
        let alert = UnopenableRecentFileAlert(
            file: UnopenableRecentFile(
                url: file, result: .unreadable, unavailableVolumeName: "Media"))

        #expect(alert == .volumeOffline(volumeName: "Media"))
        #expect(alert.defaultButton == .ok)
        #expect(!alert.removesEntry(.ok))
        #expect(alert.secondaryButton == .removeFromRecents)
        #expect(alert.removesEntry(.removeFromRecents))
    }

    /// With the volume mounted, an unreadable file really is gone, so removing leads.
    @Test
    func anUnreadableFileOnAMountedVolumeLeadsWithRemoval() {
        let alert = UnopenableRecentFileAlert(
            file: UnopenableRecentFile(
                url: file, result: .unreadable, unavailableVolumeName: nil))

        #expect(alert == .unreadable)
        #expect(alert.defaultButton == .removeFromRecents)
        #expect(alert.secondaryButton == .cancel)
        #expect(!alert.removesEntry(.cancel))
    }

    /// An unplayable file is present and intact, so it must never be described as missing. Its
    /// single OK still clears the entry, since it shouldn't have been listed in the first place.
    @Test
    func anUnplayableFileOffersOnlyOKAndStillClearsTheEntry() {
        let alert = UnopenableRecentFileAlert(
            file: UnopenableRecentFile(
                url: file, result: .unplayable, unavailableVolumeName: nil))

        #expect(alert == .unplayable)
        #expect(alert.defaultButton == .ok)
        #expect(alert.secondaryButton == nil)
        #expect(alert.removesEntry(.ok))
    }

    /// Being unplayable is about the file's contents, so it stays that diagnosis even if the
    /// volume also looks absent - "wrong format" is never a reason to blame the drive.
    @Test
    func unplayableTakesPrecedenceOverVolumeState() {
        let alert = UnopenableRecentFileAlert(
            file: UnopenableRecentFile(
                url: file, result: .unplayable, unavailableVolumeName: "Media"))

        #expect(alert == .unplayable)
    }
}
