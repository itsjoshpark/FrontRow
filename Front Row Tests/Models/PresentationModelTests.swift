//
//  PresentationModelTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

/// Who gets to ask the user something, and when.
///
/// Both alerts the model holds are stacked on the same view in each scene, so between them they
/// have one place to appear. The model is what keeps two questions out of it - and the reason is
/// worse than one of them not showing: SwiftUI settles an alert's wording when it presents it but
/// builds its buttons from whatever the value holds now, so a question swapped in under one already
/// on screen is drawn as the first one's words above the second one's buttons. It happened, and the
/// buttons acted on a file the alert did not name.
///
/// Its own instance per test rather than `PresentationModel.shared`, so nothing here waits on, or
/// disturbs, the suites driving the real one.
@MainActor
struct PresentationModelTests {

    private let film = URL(filePath: "/Movies/The Film.mkv")

    private func problem(_ url: URL) -> RemuxAlert {
        .problem(RemuxProblem(url: url, reason: .unsupported, scene: .player))
    }

    private func unopenable(_ url: URL) -> UnopenableRecentFile {
        UnopenableRecentFile(
            url: url, result: .unplayable, unavailableVolumeName: nil, scene: .player)
    }

    /// The question on screen keeps the buttons it was drawn with.
    @Test
    func aQuestionAlreadyOnScreenIsNotReplaced() {
        let model = PresentationModel()
        model.raise(problem(film))

        let tookTheFloor = model.raise(problem(URL(filePath: "/Movies/Another Film.mkv")))

        #expect(!tookTheFloor, "The second question reported that it had been raised")
        guard case .problem(let showing) = model.remuxAlert else {
            Issue.record("The question that was up went missing")
            return
        }
        #expect(showing.url == film, "The second question replaced the first")
    }

    /// Refusing is only for as long as the first question is up - the next one has to get through.
    @Test
    func aQuestionCanBeRaisedOnceTheLastIsAnswered() {
        let model = PresentationModel()
        model.raise(problem(film))
        model.dismissRemuxAlert(in: .player)

        let next = URL(filePath: "/Movies/Another Film.mkv")
        #expect(model.raise(problem(next)))
        guard case .problem(let showing) = model.remuxAlert else {
            Issue.record("Nothing was raised after the last question was answered")
            return
        }
        #expect(showing.url == next)
    }

    /// The two kinds of question share the one place to appear, so they have to queue behind each
    /// other rather than each behaving as though it were the only one.
    @Test
    func theTwoKindsOfQuestionDoNotOverwriteEachOther() {
        let model = PresentationModel()
        model.raise(problem(film))

        #expect(!model.raise(unopenable(film)), "A recent-file alert talked over a conversion")
        #expect(model.unopenableRecentFile == nil)

        model.dismissRemuxAlert(in: .player)
        #expect(model.raise(unopenable(film)))
        #expect(!model.raise(problem(film)), "A conversion talked over a recent-file alert")
        #expect(model.remuxAlert == nil)
    }

    /// Answering a question that is no longer there happens: a scene can be torn down under one.
    @Test
    func dismissingWhatIsNotThereIsHarmless() {
        let model = PresentationModel()

        model.dismissRemuxAlert(in: .player)
        model.dismissUnopenableRecentFile(in: .player)

        #expect(!model.isAskingAboutAFile)
    }

    /// Only the scene showing a question may put it away.
    ///
    /// Both scenes apply a modifier to the same value, so both are told when either is dismissed.
    /// Without this the scene that is not presenting clears the question the other is still
    /// showing - and the buttons go with it.
    @Test
    func onlyTheSceneHoldingAQuestionCanDismissIt() {
        let model = PresentationModel()
        model.raise(problem(film))

        model.dismissRemuxAlert(in: .welcome)
        #expect(model.remuxAlert != nil, "A scene that was not showing the question took it down")

        model.dismissRemuxAlert(in: .player)
        #expect(model.remuxAlert == nil)
    }

    /// Nothing is asked while a conversion runs: its sheet is sitting where the question would go,
    /// and a question raised into that is dropped by AppKit without ever being answered - which
    /// would hold the slot for good.
    @Test
    func nothingIsAskedWhileAConversionIsRunning() {
        let model = PresentationModel()
        model.conversionBegan()

        #expect(!model.raise(problem(film)))
        #expect(!model.raise(unopenable(film)))
        #expect(model.remuxAlert == nil)
        #expect(model.unopenableRecentFile == nil)

        model.conversionEnded()
        #expect(model.raise(problem(film)), "The slot stayed shut after the conversion ended")
    }

    /// Playback commands stay disabled while any question is up, which is the one thing outside
    /// this file that reads the slot.
    @Test
    func aQuestionCountsAsPresenting() {
        let model = PresentationModel()
        #expect(!model.isPresenting)

        model.raise(problem(film))

        #expect(model.isAskingAboutAFile)
        #expect(model.isPresenting)
    }
}
