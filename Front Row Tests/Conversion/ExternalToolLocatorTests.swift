//
//  ExternalToolLocatorTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

struct ExternalToolLocatorTests {

    private func locator(_ probe: FakeExecutableProbe) -> ExternalToolLocator {
        ExternalToolLocator(probe: probe)
    }

    /// The app is launched from the Finder, which hands it a `PATH` containing none of the places
    /// a package manager installs into - so the directories have to be named outright.
    @Test
    func bothToolsAreFoundInHomebrewsDirectory() {
        let tools = locator(
            FakeExecutableProbe("/opt/homebrew/bin/ffmpeg", "/opt/homebrew/bin/ffprobe")
        ).locateFFmpeg()

        #expect(tools?.ffmpeg == URL(filePath: "/opt/homebrew/bin/ffmpeg"))
        #expect(tools?.ffprobe == URL(filePath: "/opt/homebrew/bin/ffprobe"))
    }

    /// Intel Homebrew and MacPorts install elsewhere.
    @Test
    func theOtherInstallLocationsAreSearchedToo() {
        #expect(
            locator(FakeExecutableProbe("/usr/local/bin/ffmpeg", "/usr/local/bin/ffprobe"))
                .locateFFmpeg() != nil
        )
        #expect(
            locator(FakeExecutableProbe("/opt/local/bin/ffmpeg", "/opt/local/bin/ffprobe"))
                .locateFFmpeg() != nil
        )
    }

    /// ffmpeg on its own is no use: without ffprobe the streams can't be checked, and converting a
    /// file blind is how someone ends up with an MP4 that won't open.
    @Test
    func ffmpegWithoutFfprobeCountsAsUnavailable() {
        let tools = locator(FakeExecutableProbe("/opt/homebrew/bin/ffmpeg")).locateFFmpeg()

        #expect(tools == nil)
    }

    @Test
    func nothingInstalledFindsNothing() {
        #expect(locator(FakeExecutableProbe()).locateFFmpeg() == nil)
    }

    /// Which page the "no ffmpeg" alert sends someone to depends on this, so it has to be right in
    /// both directions.
    @Test
    func homebrewIsDetectedWhereverItIsInstalled() {
        #expect(locator(FakeExecutableProbe("/opt/homebrew/bin/brew")).hasHomebrew())
        #expect(locator(FakeExecutableProbe("/usr/local/bin/brew")).hasHomebrew())
        #expect(!locator(FakeExecutableProbe()).hasHomebrew())
        // ffmpeg present but brew absent is a real state - someone can install ffmpeg by hand.
        #expect(!locator(FakeExecutableProbe("/opt/homebrew/bin/ffmpeg")).hasHomebrew())
    }

    /// The first directory holding the tool wins, so a Homebrew install is preferred to an older
    /// one left behind in `/usr/local`.
    @Test
    func theSearchStopsAtTheFirstMatch() {
        let tools = locator(
            FakeExecutableProbe(
                "/opt/homebrew/bin/ffmpeg", "/opt/homebrew/bin/ffprobe",
                "/usr/local/bin/ffmpeg", "/usr/local/bin/ffprobe"
            )
        ).locateFFmpeg()

        #expect(tools?.ffmpeg.path() == "/opt/homebrew/bin/ffmpeg")
    }
}
