//
//  MediaConversion.swift
//  Front Row
//
//  Created by Joshua Park on 8/15/26.
//

import SwiftUI

/// Opening a Matroska file: work out whether it can be converted, ask, convert, play, tidy up.
///
/// AVFoundation has no Matroska demuxer, so these files never reach `PlayEngine`. Everything the
/// user sees along the way is raised from here.
@MainActor
enum MediaConversion {

    private static let ffmpegFormulaURL = URL(string: "https://formulae.brew.sh/formula/ffmpeg")!

    private static let homebrewURL = URL(string: "https://brew.sh")!

    /// Entry point for a convertible file. Ends by presenting one of the alerts above.
    static func offerConversion(of url: URL) async {
        let presented = PresentationModel.shared
        let locator = ExternalToolLocator()

        guard let tools = await locator.resolveFFmpeg() else {
            presented.remuxAlert = .problem(
                RemuxProblem(
                    url: url,
                    reason: .toolsMissing(hasHomebrew: locator.hasHomebrew()),
                    scene: hostScene()
                )
            )
            return
        }

        let media: ProbedMedia
        do {
            media = try await FFprobeStreamReader(ffprobe: tools.ffprobe).probe(url)
        } catch {
            presented.remuxAlert = .problem(
                RemuxProblem(url: url, reason: .probeFailed, scene: hostScene()))
            return
        }

        let plan = RemuxPlanner.plan(for: media.streams)
        guard case .unsupported = plan else {
            presented.remuxAlert = .offer(
                RemuxOffer(
                    url: url,
                    plan: plan,
                    duration: media.duration,
                    tools: tools,
                    scene: hostScene()
                )
            )
            return
        }

        presented.remuxAlert = .problem(
            RemuxProblem(url: url, reason: .unsupported, scene: hostScene()))
    }

    /// A conversion that is running, and what has to go if the app is asked to quit while it is.
    struct ActiveConversion {
        var task: Task<Void, Never>
        var workingURL: URL
    }

    /// The conversion running now, if there is one.
    private(set) static var activeConversion: ActiveConversion?

    /// Starts the conversion the user just approved.
    static func startConversion(_ offer: RemuxOffer) {
        guard let recipe = offer.plan.recipe else { return }

        let presented = PresentationModel.shared
        let output = RemuxOutputNaming.outputURL(for: offer.url)
        let working = RemuxOutputNaming.workingURL(besides: output)
        let remuxer = MediaRemuxer(tools: offer.tools)
        let sheet = ConversionProgressSheet(fileName: offer.url.lastPathComponent)
        presented.isConverting = true

        let task = Task {
            var failure: (any Error)?
            do {
                try await remuxer.remux(
                    input: offer.url,
                    output: working,
                    recipe: recipe,
                    duration: offer.duration
                ) { fraction in
                    Task { @MainActor in sheet.update(fraction: fraction) }
                }
            } catch {
                failure = error
            }

            // Waited on rather than fired off: whatever comes next lands on this same window, and
            // a SwiftUI alert raised while AppKit is still closing a sheet never appears.
            await sheet.dismiss()
            presented.isConverting = false
            // Only if it is still this run's. Nothing stops a second conversion being started, and
            // one that is finishing must not disown a newer one.
            if activeConversion?.workingURL == working { activeConversion = nil }

            if let failure {
                // Safe to delete: the name is one this run picked and nothing else writes to.
                try? FileManager.default.removeItem(at: working)
                presentFailure(failure, url: offer.url)
                return
            }

            do {
                // Fails rather than overwrites, so a file that appeared at the destination while
                // ffmpeg was running is left alone.
                try FileManager.default.moveItem(at: working, to: output)
            } catch {
                try? FileManager.default.removeItem(at: working)
                presentFailure(error, url: offer.url)
                return
            }

            // Asked before the converted file is opened rather than after. Starting playback
            // resizes the window to the video, and a window resized out from under a sheet
            // dismisses it - the question would appear and vanish again before it could be read.
            presented.remuxAlert = .cleanup(
                RemuxCleanup(
                    originalURL: offer.url,
                    convertedURL: output,
                    scene: offer.scene
                )
            )
        }

        activeConversion = ActiveConversion(task: task, workingURL: working)

        if let window = hostWindow() {
            sheet.present(on: window) { task.cancel() }
        }
    }

    /// Stops `conversion` and deletes what it had written.
    ///
    /// Not waited on. ffmpeg answers SIGTERM promptly, but a quit that blocked on it would be worse
    /// than one that does not: a tool still holding the file writes into an unlinked inode, and the
    /// kernel reclaims it when the tool goes.
    static func stop(_ conversion: ActiveConversion) {
        conversion.task.cancel()
        try? FileManager.default.removeItem(at: conversion.workingURL)
    }

    /// Tidies away a conversion still running when the app is asked to quit.
    ///
    /// A task is not cancelled by the process exiting and a child is not killed by its parent
    /// going, so without this the ffmpeg behind a conversion carries on encoding into a file
    /// nothing is left to move or delete.
    ///
    /// Reached only where the conversion is running without its sheet. A sheet on screen stops the
    /// app terminating at all, so the usual way to hit this - quitting mid-conversion - cannot
    /// happen; and a force quit runs none of this. What keeps those cases tidy is the working file
    /// being visible, not this.
    static func stopConversionForTermination() {
        guard let active = activeConversion else { return }
        activeConversion = nil
        stop(active)
    }

    /// Plays the converted file, then acts on the answer to the cleanup question.
    ///
    /// Deliberately in that order. The stream checks are conservative but not infallible, and if
    /// the converted file turns out not to open then the Matroska original is the only copy of the
    /// film left - so it has to survive being wrong.
    static func finishConversion(_ cleanup: RemuxCleanup, trashingOriginal: Bool) {
        Task {
            guard await openFileAndPresent(url: cleanup.convertedURL) == .opened else {
                PresentationModel.shared.remuxAlert = .problem(
                    RemuxProblem(
                        url: cleanup.convertedURL, reason: .unsupported, scene: hostScene()))
                return
            }

            if trashingOriginal {
                try? FileManager.default.trashItem(at: cleanup.originalURL, resultingItemURL: nil)
            }
        }
    }

    static func openInstallPage(hasHomebrew: Bool) {
        NSWorkspace.shared.open(hasHomebrew ? ffmpegFormulaURL : homebrewURL)
    }

    /// A cancelled conversion is a choice, not a failure, so it raises nothing.
    private static func presentFailure(_ error: any Error, url: URL) {
        let details: String
        switch error {
        case FFmpegError.cancelled, is CancellationError:
            return
        case FFmpegError.conversionFailed(let message):
            details = message
        default:
            details = error.localizedDescription
        }

        ConversionFailureAlert.present(
            fileName: url.lastPathComponent,
            details: details,
            on: hostWindow()
        )
    }

    /// The scene that will show what comes next, with a window behind it to show it in.
    ///
    /// Read at the moment of presenting rather than when the file was opened: ffprobe runs in
    /// between, and which windows exist can change while it does. Double-clicking a Matroska file
    /// in the Finder skips the welcome window and opens nothing else, so without asking for the
    /// player window here the alert would be raised against no window at all and never appear.
    private static func hostScene() -> AlertScene {
        let scene = AlertScene.current
        if scene == .player && WindowController.shared.mainWindow == nil {
            WelcomeWindowCoordinator.shared.presentMainWindow()
        }
        return scene
    }

    /// The window an AppKit sheet should hang from - the same one `hostScene()` names.
    private static func hostWindow() -> NSWindow? {
        WindowController.shared.mainWindow ?? WelcomeWindowCoordinator.shared.welcomeWindow
    }
}
