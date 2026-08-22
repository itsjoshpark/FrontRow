//
//  FileOpeningTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

/// Which failed opens get blamed on the connection.
///
/// AVFoundation reports a remote file it couldn't reach and a local file that's been deleted with
/// the same `.unreadable`, so this is the step that tells them apart - and telling them apart is
/// the difference between "you're offline" and an accusation that a file has been deleted.
struct FileOpeningTests {

    private let remote = URL(string: "https://media.example.com/clip.mp4")!
    private let local = URL(filePath: "/Volumes/Media/movie.mov")

    /// The case the whole thing exists for: a streamed file, nothing to stream it over.
    @Test func anUnreachableRemoteFileWithNoConnectionIsOffline() async {
        let result = await diagnosingOffline(
            .unreadable, url: remote, reachability: FakeNetworkReachability(connected: false))

        #expect(result == .offline)
    }

    /// With a working connection the address was genuinely tried and genuinely failed, so the
    /// file keeps the blame - a 404 must not be reported as the user's network being down.
    @Test func anUnreachableRemoteFileWithAConnectionStaysUnreadable() async {
        let result = await diagnosingOffline(
            .unreadable, url: remote, reachability: FakeNetworkReachability(connected: true))

        #expect(result == .unreadable)
    }

    /// A local file is on a disk that's there whether or not the machine is on a network. Blaming
    /// the connection would send the user to fix something unrelated while their file is missing.
    @Test func aLocalFileIsNeverBlamedOnTheConnection() async {
        let result = await diagnosingOffline(
            .unreadable, url: local, reachability: FakeNetworkReachability(connected: false))

        #expect(result == .unreadable)
    }

    /// Being unplayable is about the file's contents: it was fetched, in full, and rejected. That
    /// it happened to be fetched before the network dropped changes nothing about the diagnosis.
    @Test func anUnplayableRemoteFileIsNeverBlamedOnTheConnection() async {
        let result = await diagnosingOffline(
            .unplayable, url: remote, reachability: FakeNetworkReachability(connected: false))

        #expect(result == .unplayable)
    }

    /// Results that aren't failures pass through untouched, so a success can never be rewritten
    /// into an error by a connection that dropped just after the file opened.
    @Test(arguments: [FileOpenResult.opened, .handedToConverter])
    func anythingButAnUnreadableFileIsLeftAlone(result: FileOpenResult) async {
        let diagnosed = await diagnosingOffline(
            result, url: remote, reachability: FakeNetworkReachability(connected: false))

        #expect(diagnosed == result)
    }
}
