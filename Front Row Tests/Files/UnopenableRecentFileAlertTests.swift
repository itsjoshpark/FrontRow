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
                url: file, result: .unreadable, unavailableVolumeName: "Media", scene: .player))

        #expect(alert == .volumeOffline(volumeName: "Media"))
        #expect(alert.defaultButton == .ok)
        #expect(!alert.removesEntry(.ok))
        #expect(alert.secondaryButton == .removeFromRecents)
        #expect(alert.removesEntry(.removeFromRecents))
    }

    /// With the volume mounted, the recoverable case has already been ruled out - so an unreadable
    /// file is taken as gone, and its single OK clears the entry rather than just dismissing.
    @Test
    func anUnreadableFileOffersOnlyOKAndClearsTheEntry() {
        let alert = UnopenableRecentFileAlert(
            file: UnopenableRecentFile(
                url: file, result: .unreadable, unavailableVolumeName: nil, scene: .player))

        #expect(alert == .unreadable)
        #expect(alert.defaultButton == .ok)
        #expect(alert.secondaryButton == nil)
        #expect(alert.removesEntry(.ok))
    }

    /// A file nothing could be reached over says nothing about the file, so dismissing must leave
    /// the entry alone - the connection is coming back, and the wording blames no file at all.
    @Test
    func aMissingConnectionIsDiagnosedAndDismissesWithoutRemoving() {
        let alert = UnopenableRecentFileAlert(
            file: UnopenableRecentFile(
                url: file, result: .offline, unavailableVolumeName: nil, scene: .player))

        #expect(alert == .offline)
        #expect(alert.defaultButton == .ok)
        #expect(!alert.removesEntry(.ok))
        #expect(alert.secondaryButton == nil)
    }

    /// Being offline is about reaching the file at all, so it's settled before the volume is
    /// consulted. Only a remote file is ever diagnosed that way and a remote file has no volume,
    /// so the two can't really meet - this pins the order anyway, since a later reshuffle of the
    /// switch would otherwise be free to describe a URL as living on a drive.
    @Test
    func offlineTakesPrecedenceOverVolumeState() {
        let alert = UnopenableRecentFileAlert(
            file: UnopenableRecentFile(
                url: file, result: .offline, unavailableVolumeName: "Media", scene: .player))

        #expect(alert == .offline)
    }

    /// An unplayable file is present and intact, so it must never be described as missing. Its
    /// single OK still clears the entry, since it shouldn't have been listed in the first place.
    @Test
    func anUnplayableFileOffersOnlyOKAndStillClearsTheEntry() {
        let alert = UnopenableRecentFileAlert(
            file: UnopenableRecentFile(
                url: file, result: .unplayable, unavailableVolumeName: nil, scene: .player))

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
                url: file, result: .unplayable, unavailableVolumeName: "Media", scene: .player))

        #expect(alert == .unplayable)
    }
}
