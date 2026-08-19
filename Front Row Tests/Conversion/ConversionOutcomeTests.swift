//
//  ConversionOutcomeTests.swift
//  Front Row Tests
//

import AppKit
import Foundation
import Testing

@testable import Front_Row

extension ConversionSuites {
    /// How a conversion ends: what it leaves on disk, and what it asks the user next.
    ///
    /// `MediaConversion` runs ffmpeg into a working file and only moves it into place if the tool
    /// finished. Each way out of that - it worked, ffmpeg gave up, the user changed their mind, the
    /// name was taken - leaves the directory in a different state, and only one of them may leave
    /// anything behind.
    ///
    /// The failure alert itself is not asserted here. It is an AppKit sheet hung off whichever
    /// window `MediaConversion` finds, and the suites that own those windows run alongside this one
    /// - so which window it lands on is not this suite's to know. What the alerts say is
    /// `RemuxAlertTests`'.
    @MainActor
    @Suite(.serialized)
    struct ConversionOutcomeTests {

        private let recipe = RemuxRecipe(
            videoIndex: 0,
            videoTag: "avc1",
            audio: [],
            subtitleIndices: [],
            droppedSubtitles: []
        )

        private func makeDirectory() throws -> URL {
            let directory = URL.cachesDirectory.appending(
                path: "FrontRowOutcome-\(UUID().uuidString)")
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            return directory
        }

        private func makeOffer(
            _ tool: ScriptedTool, in directory: URL, scene: AlertScene = .player
        ) -> RemuxOffer {
            RemuxOffer(
                url: directory.appending(path: "The Film.mkv"),
                plan: .remux(recipe),
                duration: 2,
                tools: FFmpegTools(ffmpeg: tool.url, ffprobe: tool.url),
                scene: scene
            )
        }

        private func contents(of directory: URL) throws -> [String] {
            try FileManager.default.contentsOfDirectory(
                atPath: directory.path(percentEncoded: false)
            )
            .sorted()
        }

        /// Waits for the conversion's task to finish, which it reports by putting the flag back.
        private func waitUntilFinished() async {
            let deadline = ContinuousClock.now + .seconds(30)
            while ContinuousClock.now < deadline {
                if !PresentationModel.shared.isConverting { return }
                try? await Task.sleep(for: .milliseconds(20))
            }
        }

        /// Runs `body` with a window for the alerts to hang from, and clears up after it.
        private func withHostWindow(_ body: () async throws -> Void) async rethrows {
            let window = NSWindow(
                contentRect: CGRect(x: 0, y: 0, width: 480, height: 270),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: true
            )
            // Released by ARC rather than by AppKit, and on the screen: a sheet does not attach to
            // a window that was never ordered front.
            window.isReleasedWhenClosed = false
            window.title = "Front Row Tests"
            window.orderFront(nil)

            // Both slots, because `MediaConversion` takes the first that answers and a failure
            // with neither falls back to `runModal()`, which in a test host blocks the run for good
            // rather than failing it.
            let savedWelcome = WelcomeWindowCoordinator.shared.welcomeWindow
            WindowController.shared.setMainWindow(window)
            WelcomeWindowCoordinator.shared.welcomeWindow = window

            defer {
                // Wherever the sheet landed, it goes before the next test runs.
                for open in NSApp.windows {
                    while let sheet = open.attachedSheet { open.endSheet(sheet) }
                }
                WindowController.shared.releaseMainWindow(window)
                WelcomeWindowCoordinator.shared.welcomeWindow = savedWelcome
                window.orderOut(nil)
                // Both scenes, since this is a reset and must not depend on where a test's
                // question landed.
                PresentationModel.shared.dismissRemuxAlert(in: .player)
                PresentationModel.shared.dismissRemuxAlert(in: .welcome)
                PresentationModel.shared.conversionEnded()
            }

            try await body()
        }

        // MARK: - One file at a time

        /// A Matroska opened while another is converting is turned away at the door.
        ///
        /// It used to be let through, and the two questions then shared one alert slot: the words
        /// of the second appeared above the buttons of the first, so "Front Row can open Film B
        /// after it is converted" came with Move to Trash and Keep - and Move to Trash took Film
        /// A's original, a file the alert never named.
        @Test(.timeLimit(.minutes(1)))
        func aFileOpenedDuringAConversionDoesNotTakeTheAlertSlot() async {
            PresentationModel.shared.conversionBegan()
            defer { PresentationModel.shared.conversionEnded() }

            await MediaConversion.offerConversion(of: URL(filePath: "/Movies/Film B.mkv"))

            #expect(
                PresentationModel.shared.remuxAlert == nil,
                "A second file raised a question over a conversion that was already running")
        }

        /// The same where the first file's own question is still up and unanswered.
        @Test(.timeLimit(.minutes(1)))
        func aFileOpenedWhileAQuestionIsUpDoesNotReplaceIt() async {
            let waiting = RemuxProblem(
                url: URL(filePath: "/Movies/Film A.mkv"), reason: .unsupported, scene: .player)
            PresentationModel.shared.raise(.problem(waiting))
            defer { PresentationModel.shared.dismissRemuxAlert(in: .player) }

            await MediaConversion.offerConversion(of: URL(filePath: "/Movies/Film B.mkv"))

            guard case .problem(let still) = PresentationModel.shared.remuxAlert else {
                Issue.record("The question that was already up was replaced")
                return
            }
            #expect(still.url.lastPathComponent == "Film A.mkv")
        }

        /// ffmpeg gave up part of the way through, and the half file goes with it.
        ///
        /// The half file is the point. It is a real, visible file beside the user's film, and one
        /// left there would look to them like the conversion half worked. Nothing is asked of them
        /// either: the original is still the only copy, so the question about trashing it belongs
        /// only to a conversion that produced something.
        @Test(.timeLimit(.minutes(1)))
        func aFailedConversionDeletesItsWorkingFile() async throws {
            let tool = try ScriptedTool.writingPartialOutput(bytes: 4096)
            defer { tool.remove() }
            let directory = try makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }

            try await withHostWindow {
                MediaConversion.startConversion(makeOffer(tool, in: directory))
                await waitUntilFinished()

                let left = try contents(of: directory)
                #expect(left == [], "The failed conversion left a file behind")
                #expect(
                    PresentationModel.shared.remuxAlert == nil,
                    "A conversion that failed still asked about trashing the original")
            }
        }

        /// The user changed their mind, and the half file goes with that too.
        ///
        /// Cancelling is a choice, not a failure, so nothing is put to the user afterwards - an
        /// alert here would be the app complaining about something they just asked for.
        @Test(.timeLimit(.minutes(1)))
        func aCancelledConversionDeletesItsWorkingFile() async throws {
            let tool = try ScriptedTool.writingPartialOutputThenWaiting(bytes: 4096)
            defer { tool.remove() }
            let directory = try makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }

            try await withHostWindow {
                MediaConversion.startConversion(makeOffer(tool, in: directory))

                #expect(
                    await tool.waitUntilReady(),
                    "ffmpeg never wrote its working file, so there was nothing to clean up")
                // Cancelled the way the sheet's Cancel button does, rather than through anything
                // that tidies up itself - what is under test is the conversion's own clearing up.
                MediaConversion.activeConversion?.task.cancel()
                await waitUntilFinished()

                let left = try contents(of: directory)
                #expect(left == [], "The cancelled conversion left a file behind")
                #expect(
                    PresentationModel.shared.remuxAlert == nil,
                    "Cancelling raised a question of its own")
            }
        }

        /// ffmpeg was killed from outside the app, and the half file still goes.
        ///
        /// Nothing here asked it to stop, so the app finds out the same way it finds out about any
        /// other bad end: a tool that stopped without finishing. Worth its own test because it
        /// arrives by a different route to a tool that gave up on its own - an uncaught signal
        /// rather than an exit - and a stray working file beside the film is what a mishandled one
        /// would leave.
        @Test(.timeLimit(.minutes(1)))
        func aConversionWhoseToolIsKilledDeletesItsWorkingFile() async throws {
            let tool = try ScriptedTool.killedPartWayThrough(bytes: 4096)
            defer { tool.remove() }
            let directory = try makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }

            try await withHostWindow {
                MediaConversion.startConversion(makeOffer(tool, in: directory))
                await waitUntilFinished()

                let left = try contents(of: directory)
                #expect(left == [], "A killed conversion left its working file behind")
                #expect(
                    PresentationModel.shared.remuxAlert == nil,
                    "A killed conversion still asked about trashing the original")
            }
        }

        /// The question about the original is asked wherever there is a window to ask it in, not
        /// wherever the offer was accepted.
        ///
        /// A conversion can outlast the window it started in - a player window appears for a file
        /// handed to the app, and the welcome window gives way to it. An offer accepted in the
        /// welcome scene that finished after that would raise its question into a scene with
        /// nothing to show it: never presented, never answered, and holding the one slot every
        /// later question needs.
        @Test(.timeLimit(.minutes(1)))
        func aFinishedConversionAsksInTheSceneThatHasAWindow() async throws {
            let tool = try ScriptedTool.writingPartialOutput(bytes: 4096, exiting: 0)
            defer { tool.remove() }
            let directory = try makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }

            await withHostWindow {
                // Offered in the welcome scene; by the time it finishes the player window is the
                // one on screen, which is what `withHostWindow` has installed.
                MediaConversion.startConversion(makeOffer(tool, in: directory, scene: .welcome))
                await waitUntilFinished()

                guard case .cleanup(let cleanup) = PresentationModel.shared.remuxAlert else {
                    Issue.record("The converted file raised no question about the original")
                    return
                }
                #expect(
                    cleanup.scene == .player,
                    "The question was raised into the scene the offer came from, which has no window"
                )
            }
        }

        /// Something took the output name while ffmpeg was working: the conversion is thrown away
        /// rather than written over the top of it.
        ///
        /// The name is picked before ffmpeg starts and the move happens minutes later, so anything
        /// arriving in between belongs to someone else. Losing the conversion is the right way
        /// round - it can be run again, and the file that was there cannot.
        @Test(.timeLimit(.minutes(1)))
        func aConversionWhoseOutputNameWasTakenIsThrownAway() async throws {
            let tool = try ScriptedTool.writingPartialOutputThenWaiting(bytes: 4096, seconds: 3)
            defer { tool.remove() }
            let directory = try makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }

            try await withHostWindow {
                MediaConversion.startConversion(makeOffer(tool, in: directory))

                #expect(await tool.waitUntilReady(), "ffmpeg never got as far as writing anything")
                // Arrives after the name was chosen and before the conversion is moved into it.
                let occupier = Data("someone else's film".utf8)
                try occupier.write(to: directory.appending(path: "The Film.mp4"))

                await waitUntilFinished()

                let left = try contents(of: directory)
                #expect(left == ["The Film.mp4"], "The conversion left its working file behind")
                #expect(
                    try Data(contentsOf: directory.appending(path: "The Film.mp4")) == occupier,
                    "The file that was already there was written over"
                )
                #expect(
                    PresentationModel.shared.remuxAlert == nil,
                    "A conversion that came to nothing still asked about trashing the original")
            }
        }

        /// It worked: the working file becomes the output, and the question about the original is
        /// put to the user.
        @Test(.timeLimit(.minutes(1)))
        func aFinishedConversionMovesItsWorkingFileIntoPlace() async throws {
            let tool = try ScriptedTool.writingPartialOutput(bytes: 4096, exiting: 0)
            defer { tool.remove() }
            let directory = try makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }

            try await withHostWindow {
                MediaConversion.startConversion(makeOffer(tool, in: directory))
                await waitUntilFinished()

                let left = try contents(of: directory)
                #expect(left == ["The Film.mp4"])

                guard case .cleanup(let cleanup) = PresentationModel.shared.remuxAlert else {
                    Issue.record("The converted file raised no question about the original")
                    return
                }
                #expect(cleanup.convertedURL.lastPathComponent == "The Film.mp4")
                #expect(cleanup.originalURL.lastPathComponent == "The Film.mkv")
            }
        }
    }
}
