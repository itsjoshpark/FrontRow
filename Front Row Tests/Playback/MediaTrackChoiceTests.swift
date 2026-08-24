//
//  MediaTrackChoiceTests.swift
//  Front Row Tests
//
//  Created by Joshua Park on 8/24/26.
//

import Testing

@testable import Front_Row

/// How an entry in the Audio Track and Subtitle menus gets its name.
@Suite struct MediaTrackChoiceTests {

    @Test func titleAndLanguageReadTogether() {
        #expect(
            MediaTrackChoice.name(
                title: "Director’s Commentary",
                languageTag: "en",
                describedName: "English",
                index: 2
            ) == "Director’s Commentary (English)")
    }

    /// An untagged track gets no parenthetical, rather than one saying nothing.
    @Test func aTitleWithNoLanguageStandsAlone() {
        #expect(
            MediaTrackChoice.name(
                title: "Commentary", languageTag: "und", describedName: nil, index: 1
            ) == "Commentary")
    }

    /// An HLS rendition's `NAME` arrives as the track's title, with no language beside it.
    @Test func aStreamRenditionIsNamedByItsTitle() {
        #expect(
            MediaTrackChoice.name(
                title: "Commentary", languageTag: nil, describedName: "Unknown", index: 1
            ) == "Commentary")
    }

    /// What AVFoundation adds to a language is worth keeping.
    @Test func aQualifiedNameIsKeptIntact() {
        #expect(
            MediaTrackChoice.name(
                title: nil, languageTag: "en", describedName: "English (SDH)", index: 1
            ) == "English (SDH)")
    }

    /// No language tag at all is not the same as a tag saying the language is unknown.
    @Test func anUntaggedCaptionKeepsItsName() {
        #expect(
            MediaTrackChoice.name(
                title: nil, languageTag: nil, describedName: "CC", index: 1
            ) == "CC")
    }

    /// The name AVFoundation builds out of `und` is the placeholder this rule exists to replace.
    @Test func undeterminedLanguageIsNumberedInstead() {
        #expect(
            MediaTrackChoice.name(
                title: nil, languageTag: "und", describedName: "Unknown language", index: 1
            ) == "Track 1")
    }

    @Test func aLanguageAloneNamesTheTrack() {
        #expect(
            MediaTrackChoice.name(
                title: nil, languageTag: "fr", describedName: nil, index: 3
            ) == "French")
    }

    /// A track with nothing to go on is numbered within its own kind, so the only audio track in a
    /// file is the first one whatever else the file holds.
    @Test(arguments: [1, 2, 3])
    func anAnonymousTrackIsNumbered(index: Int) {
        #expect(
            MediaTrackChoice.name(
                title: nil, languageTag: nil, describedName: nil, index: index
            ) == "Track \(index)")
    }

    @Test func anEmptyTitleCountsAsNoTitle() {
        #expect(
            MediaTrackChoice.name(
                title: "", languageTag: "en", describedName: nil, index: 1
            ) == "English")
    }
}
