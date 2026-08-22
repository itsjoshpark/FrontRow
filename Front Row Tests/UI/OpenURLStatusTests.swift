//
//  OpenURLStatusTests.swift
//  Front Row Tests
//

import Testing

@testable import Front_Row

/// What the Open URL sheet draws beside its field.
///
/// The symbol is the sheet's whole explanation - there is no message next to it - so blaming the
/// wrong thing here leaves the user retyping a perfectly good address.
struct OpenURLStatusTests {

    /// Nothing was reached, so the picture is of the connection rather than the file.
    @Test func offlineShowsTheNetworkSymbol() {
        #expect(OpenURLStatus.offline.symbolName == "network.slash")
    }

    /// The address was reached and still wouldn't play, which is the file's problem to own.
    @Test func unopenableShowsThePlaybackSymbol() {
        #expect(OpenURLStatus.unopenable.symbolName == "play.slash")
    }

    /// Nothing has gone wrong yet, so nothing is drawn - an idle sheet must not look like a
    /// failed one, and a loading sheet already has its spinner.
    @Test(arguments: [OpenURLStatus.idle, .loading])
    func aSheetThatHasNotFailedShowsNoSymbol(status: OpenURLStatus) {
        #expect(status.symbolName == nil)
    }

    /// The result travels from `openFile` to the symbol, so this is the mapping that decides
    /// which of the two failures the user is shown.
    @Test func onlyAnOfflineResultIsBlamedOnTheConnection() {
        #expect(OpenURLStatus(failure: .offline) == .offline)
        #expect(OpenURLStatus(failure: .unreadable) == .unopenable)
        #expect(OpenURLStatus(failure: .unplayable) == .unopenable)
    }
}
