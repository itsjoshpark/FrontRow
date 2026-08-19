//
//  ConvertibleFileTests.swift
//  Front Row Tests
//

import Foundation
import Testing
import UniformTypeIdentifiers

@testable import Front_Row

/// Which files are handed to the converter rather than to AVFoundation.
///
/// The first fork every opened file goes through, and the one that decides whether the conversion
/// dialogs are raised at all. A file wrongly called convertible never reaches the player; one
/// wrongly called playable reaches AVFoundation, which has no Matroska demuxer and simply fails.
@MainActor
struct ConvertibleFileTests {

    /// Matroska is the whole reason the converter exists, and the Finder does not care how the
    /// extension is typed.
    @Test
    func matroskaIsHandedToTheConverter() {
        #expect(PlayEngine.isConvertible(URL(filePath: "/Movies/The Film.mkv")))
        #expect(PlayEngine.isConvertible(URL(filePath: "/Movies/The Film.MKV")))
        #expect(PlayEngine.isConvertible(URL(filePath: "/Movies/The Film.Mkv")))
    }

    /// Everything AVFoundation opens has to go straight to the player - offering to convert a file
    /// that already plays would be a conversion for nothing.
    @Test
    func everythingAVFoundationOpensIsNot() {
        let playable = ["film.mp4", "film.m4v", "film.mov", "song.mp3", "song.m4a", "film.wav"]

        for name in playable {
            #expect(
                !PlayEngine.isConvertible(URL(filePath: "/Movies/\(name)")),
                "\(name) was sent to the converter")
        }
    }

    /// A file with nothing to go on is the player's problem, not the converter's.
    @Test
    func aFileWithNoExtensionIsNot() {
        #expect(!PlayEngine.isConvertible(URL(filePath: "/Movies/The Film")))
    }

    /// Open URL hands remote addresses to the same entry point, and the converter can only read a
    /// file on disk - ffprobe is given a path, not a URL to fetch.
    @Test
    func aRemoteMatroskaIsNotConverted() throws {
        let remote = try #require(URL(string: "https://example.com/The Film.mkv"))

        #expect(!PlayEngine.isConvertible(remote))
    }

    /// The Open panel and drag and drop filter on content types while the converter matches on the
    /// extension. A convertible extension the panel will not show is one the user can only open by
    /// dropping it.
    @Test
    func everyConvertibleExtensionIsOfferedByTheOpenPanel() throws {
        for fileExtension in PlayEngine.convertibleFileExtensions {
            let type = try #require(
                UTType(filenameExtension: fileExtension),
                "\(fileExtension) resolves to no content type on this Mac")
            #expect(
                PlayEngine.openableFileTypes.contains(type),
                "\(fileExtension) is convertible but the Open panel does not offer it")
        }
    }
}
