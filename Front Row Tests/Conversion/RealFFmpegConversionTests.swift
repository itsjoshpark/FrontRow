//
//  RealFFmpegConversionTests.swift
//  Front Row Tests
//
//  Created by Joshua Park on 8/17/26.
//

import AVFoundation
import Foundation
import Testing

@testable import Front_Row

/// Whether there is an ffmpeg to test against. Read outside the suite, since a trait cannot ask
/// the type it is attached to.
private let ffmpegIsInstalled = ExternalToolLocator().locateFFmpeg() != nil

extension ConversionSuites {
    /// The whole conversion, against the ffmpeg that is actually installed.
    ///
    /// Every other test of this feature substitutes a script for ffmpeg, which is the right way to
    /// test process handling and says nothing about whether the arguments are right. These run the
    /// real thing end to end - locate, probe, plan, remux - and then ask AVFoundation to open what
    /// came out, which is the only question the feature exists to answer.
    ///
    /// Skipped where ffmpeg is not installed. The fixture is written by ffmpeg rather than committed:
    /// Matroska cannot be written without it, and a test that needs ffmpeg to run has no use for a
    /// fixture that exists to avoid needing ffmpeg.
    @Suite(.enabled(if: ffmpegIsInstalled), .serialized)
    struct RealFFmpegConversionTests {

        private func makeDirectory() throws -> URL {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            let directory = caches.appending(path: "FrontRowFFmpeg-\(UUID().uuidString)")
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            return directory
        }

        /// A two-second Matroska file of H.264 video and AC-3 audio.
        ///
        /// Chosen to produce a recipe worth running rather than a trivial one: H.264 needs an `avc1`
        /// tag to be playable from an MP4 at all, and AC-3 is copyable, so what comes out has to be
        /// right on both counts.
        private func makeMatroska(in directory: URL, seconds: Int = 2) async throws -> URL {
            let url = directory.appending(path: "fixture.mkv")
            let tools = try #require(ExternalToolLocator().locateFFmpeg())

            let output = try await ExternalProcess.run(
                tools.ffmpeg,
                arguments: [
                    "-nostdin", "-loglevel", "error", "-y",
                    "-f", "lavfi", "-i", "testsrc=size=320x180:rate=10:duration=\(seconds)",
                    "-f", "lavfi", "-i", "sine=frequency=440:duration=\(seconds)",
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "ac3",
                    url.path(percentEncoded: false),
                ],
                timeout: .seconds(120)
            )
            guard output.didSucceed else {
                Issue.record("Could not write the fixture: \(output.standardError)")
                throw FFmpegError.cancelled
            }
            return url
        }

        // MARK: - Finding the tools

        @Test
        func bothToolsAreFoundTogether() {
            let tools = ExternalToolLocator().locateFFmpeg()
            #expect(tools?.ffmpeg.lastPathComponent == "ffmpeg")
            #expect(tools?.ffprobe.lastPathComponent == "ffprobe")
        }

        /// The encoder is chosen by asking ffmpeg what it was built with, so the answer has to be one
        /// of the two names the arguments know how to use.
        @Test(.timeLimit(.minutes(1)))
        func theAACEncoderIsOneFfmpegHas() async throws {
            let tools = try #require(await ExternalToolLocator().resolveFFmpeg())
            #expect(["aac", "aac_at"].contains(tools.aacEncoder))
        }

        // MARK: - Probing

        @Test(.timeLimit(.minutes(2)))
        func probingFindsTheStreamsThatWereWritten() async throws {
            let directory = try makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }

            let tools = try #require(ExternalToolLocator().locateFFmpeg())
            let fixture = try await makeMatroska(in: directory)

            let probed = try await FFprobeStreamReader(ffprobe: tools.ffprobe).probe(fixture)

            #expect(probed.streams.contains { $0.kind == .video && $0.codecName == "h264" })
            #expect(probed.streams.contains { $0.kind == .audio && $0.codecName == "ac3" })
        }

        /// ffprobe on something that is not media reports a failure rather than decoding to nothing.
        @Test(.timeLimit(.minutes(1)))
        func probingRubbishFails() async throws {
            let directory = try makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }

            let tools = try #require(ExternalToolLocator().locateFFmpeg())
            let rubbish = directory.appending(path: "rubbish.mkv")
            try Data(repeating: 0xAB, count: 4_096).write(to: rubbish)

            await #expect(throws: FFmpegError.self) {
                try await FFprobeStreamReader(ffprobe: tools.ffprobe).probe(rubbish)
            }
        }

        // MARK: - Planning

        @Test(.timeLimit(.minutes(2)))
        func h264AndAC3PlanAsAStraightRemux() async throws {
            let directory = try makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }

            let tools = try #require(ExternalToolLocator().locateFFmpeg())
            let fixture = try await makeMatroska(in: directory)
            let probed = try await FFprobeStreamReader(ffprobe: tools.ffprobe).probe(fixture)

            let plan = RemuxPlanner.plan(for: probed.streams)
            let recipe = try #require(plan.recipe)

            // AC-3 is on the copyable list, so nothing is re-encoded.
            #expect(!recipe.transcodesAudio)
            // Without the tag the MP4 is written as avc3, which AVFoundation will not open.
            #expect(recipe.videoTag == "avc1")
            #expect(recipe.videoIndex != nil)
            #expect(recipe.audio.count == 1)
        }

        // MARK: - The whole thing

        /// Locate, probe, plan, remux - and then open the result the way the app does.
        ///
        /// This is the test the feature is for. Everything upstream of it can be right while the file
        /// that comes out still refuses to open, which is precisely what the `-tag:v` argument exists
        /// to prevent.
        @Test(.timeLimit(.minutes(3)))
        func theConvertedFileOpensInAVFoundation() async throws {
            let directory = try makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }

            let tools = try #require(await ExternalToolLocator().resolveFFmpeg())
            let fixture = try await makeMatroska(in: directory)
            let probed = try await FFprobeStreamReader(ffprobe: tools.ffprobe).probe(fixture)
            let recipe = try #require(RemuxPlanner.plan(for: probed.streams).recipe)

            let output = directory.appending(path: "converted.mp4")
            let fractions = Fractions()

            try await MediaRemuxer(tools: tools).remux(
                input: fixture, output: output, recipe: recipe, duration: 2
            ) { fractions.append($0) }

            #expect(FileManager.default.fileExists(atPath: output.path(percentEncoded: false)))
            #expect(fractions.value.last == 1, "The conversion never reported that it had finished")

            let asset = AVURLAsset(url: output)
            #expect(
                try await asset.load(.isPlayable), "ffmpeg wrote a file AVFoundation will not play")

            let tracks = try await asset.load(.tracks)
            #expect(tracks.contains { $0.mediaType == .video })
            #expect(tracks.contains { $0.mediaType == .audio })

            // The video has to arrive at the size it went in at, or the window would be shaped to a
            // file the user never chose.
            let video = try #require(tracks.first { $0.mediaType == .video })
            let size = try await video.load(.naturalSize)
            #expect(size == CGSize(width: 320, height: 180))
        }

        /// The whole path the app takes: convert into the working file, then move it into place.
        ///
        /// The working file's extension names no muxer - so ffmpeg has to be told its
        /// output format outright or it refuses the conversion before it starts. Nothing above this
        /// would notice: the arguments test only proves `-f mp4` is in the list, and every other
        /// conversion here writes straight to a `.mp4`.
        @Test(.timeLimit(.minutes(3)))
        func aConversionWrittenToItsWorkingFileIsPlayableOnceMovedIntoPlace() async throws {
            let directory = try makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }

            let tools = try #require(await ExternalToolLocator().resolveFFmpeg())
            let fixture = try await makeMatroska(in: directory)
            let probed = try await FFprobeStreamReader(ffprobe: tools.ffprobe).probe(fixture)
            let recipe = try #require(RemuxPlanner.plan(for: probed.streams).recipe)

            let output = RemuxOutputNaming.outputURL(for: fixture)
            let working = RemuxOutputNaming.workingURL(besides: output)

            try await MediaRemuxer(tools: tools).remux(
                input: fixture, output: working, recipe: recipe, duration: 2
            ) { _ in }

            #expect(
                FileManager.default.fileExists(atPath: working.path(percentEncoded: false)),
                "ffmpeg wrote nothing to the working file")
            try FileManager.default.moveItem(at: working, to: output)

            #expect(try await AVURLAsset(url: output).load(.isPlayable))
            // The working file is a rename away from the output, so finishing leaves nothing over.
            #expect(!FileManager.default.fileExists(atPath: working.path(percentEncoded: false)))
        }

        /// The MP4 an audio-only Matroska produces, which has no video track to tag.
        @Test(.timeLimit(.minutes(3)))
        func anAudioOnlyFileConvertsToSomethingPlayable() async throws {
            let directory = try makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }

            let tools = try #require(await ExternalToolLocator().resolveFFmpeg())
            let fixture = directory.appending(path: "audio.mkv")
            let written = try await ExternalProcess.run(
                tools.ffmpeg,
                arguments: [
                    "-nostdin", "-loglevel", "error", "-y",
                    "-f", "lavfi", "-i", "sine=frequency=440:duration=2",
                    "-c:a", "ac3", fixture.path(percentEncoded: false),
                ],
                timeout: .seconds(120)
            )
            try #require(written.didSucceed)

            let probed = try await FFprobeStreamReader(ffprobe: tools.ffprobe).probe(fixture)
            let recipe = try #require(RemuxPlanner.plan(for: probed.streams).recipe)
            #expect(recipe.videoIndex == nil)

            let output = directory.appending(path: "converted.m4a")
            try await MediaRemuxer(tools: tools).remux(
                input: fixture, output: output, recipe: recipe, duration: 2
            ) { _ in }

            let asset = AVURLAsset(url: output)
            #expect(try await asset.load(.isPlayable))
        }

        /// A file already at the output path is left alone - and the conversion reports success anyway.
        ///
        /// `-n` makes ffmpeg refuse to overwrite, which is the important half: the file that was there
        /// survives. But ffmpeg exits 0 while refusing, so `remux` sees a clean exit, reports a
        /// fraction of 1 and returns without having written anything.
        ///
        /// The app does not reach this. `RemuxOutputNaming` will not hand out an output name whose
        /// working file is already there, and the move to the real name afterwards fails rather than
        /// replacing. Anything else calling `MediaRemuxer` directly has to know that a successful
        /// return is not by itself proof that a file was written.
        @Test(.timeLimit(.minutes(3)))
        func anOutputThatAlreadyExistsSurvivesAConversionThatClaimsToHaveWorked() async throws {
            let directory = try makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }

            let tools = try #require(await ExternalToolLocator().resolveFFmpeg())
            let fixture = try await makeMatroska(in: directory)
            let probed = try await FFprobeStreamReader(ffprobe: tools.ffprobe).probe(fixture)
            let recipe = try #require(RemuxPlanner.plan(for: probed.streams).recipe)

            let output = directory.appending(path: "taken.mp4")
            let existing = Data("not a movie".utf8)
            try existing.write(to: output)

            try await MediaRemuxer(tools: tools).remux(
                input: fixture, output: output, recipe: recipe, duration: 2
            ) { _ in }

            #expect(
                try Data(contentsOf: output) == existing, "The file that was there was overwritten")
        }

        /// A real ffmpeg, cancelled part-way, leaves nothing running.
        ///
        /// The scripted equivalent proves the process handling; this proves ffmpeg itself answers the
        /// signal, which is what decides whether cancelling returns at all.
        @Test(.timeLimit(.minutes(3)))
        func cancellingARealConversionLeavesNoFfmpegBehind() async throws {
            let directory = try makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }

            let tools = try #require(await ExternalToolLocator().resolveFFmpeg())
            // Long enough that a re-encode is still going when the cancellation arrives.
            let fixture = try await makeMatroska(in: directory, seconds: 60)
            let probed = try await FFprobeStreamReader(ffprobe: tools.ffprobe).probe(fixture)
            var recipe = try #require(RemuxPlanner.plan(for: probed.streams).recipe)
            recipe.audio = recipe.audio.map {
                PlannedAudio(
                    index: $0.index, codecName: $0.codecName, channels: $0.channels,
                    transcodes: true)
            }

            let output = directory.appending(path: "cancelled.mp4")
            let remuxer = MediaRemuxer(tools: tools)
            let task = Task {
                try await remuxer.remux(
                    input: fixture, output: output, recipe: recipe, duration: 60
                ) { _ in }
            }

            #expect(
                await started(writingTo: output),
                "ffmpeg never started, so there was nothing for the cancellation to stop"
            )
            task.cancel()
            await #expect(throws: FFmpegError.cancelled) { try await task.value }

            #expect(
                await stopped(writingTo: output),
                "An ffmpeg was still writing the output after the conversion was cancelled"
            )
        }

        /// A real ffmpeg killed from outside the app, which is the one ending nothing here chose.
        ///
        /// Activity Monitor, a `kill`, the machine running out of memory. The app is not told and
        /// cannot be: all it sees is a tool that stopped without finishing, so it has to read that
        /// as a failure rather than as the user changing their mind - a cancellation is silent, and
        /// this must not be. SIGKILL rather than SIGTERM so ffmpeg has no chance to tidy up or to
        /// say anything on its way out, which is the harshest version of the case.
        @Test(.timeLimit(.minutes(3)))
        func aRealFfmpegKilledFromOutsideIsReportedAsAFailure() async throws {
            let directory = try makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }

            let tools = try #require(await ExternalToolLocator().resolveFFmpeg())
            let fixture = try await makeMatroska(in: directory, seconds: 60)
            let probed = try await FFprobeStreamReader(ffprobe: tools.ffprobe).probe(fixture)
            var recipe = try #require(RemuxPlanner.plan(for: probed.streams).recipe)
            recipe.audio = recipe.audio.map {
                PlannedAudio(
                    index: $0.index, codecName: $0.codecName, channels: $0.channels,
                    transcodes: true)
            }

            let output = directory.appending(path: "killed.mp4.frconverting")
            let remuxer = MediaRemuxer(tools: tools)
            let task = Task {
                try await remuxer.remux(
                    input: fixture, output: output, recipe: recipe, duration: 60
                ) { _ in }
            }

            #expect(
                await started(writingTo: output),
                "ffmpeg never started, so there was nothing to kill")
            // The command line matches the moment the tool is exec'd, a beat before it has opened
            // its output - so waiting on the process alone would kill it with nothing written yet.
            #expect(await appeared(output), "ffmpeg never opened its output file")
            kill(writingTo: output)

            do {
                try await task.value
                Issue.record("A killed ffmpeg was reported as a conversion that worked")
            } catch FFmpegError.cancelled {
                Issue.record("A killed ffmpeg was read as the user cancelling, which says nothing")
            } catch FFmpegError.conversionFailed {
                // What it is, and what raises the alert that tells the user.
            }

            #expect(await stopped(writingTo: output))
            // Left where it fell: clearing it up is `MediaConversion`'s half of this.
            #expect(FileManager.default.fileExists(atPath: output.path(percentEncoded: false)))
        }

        /// Waits until there is something at `url`.
        private func appeared(_ url: URL, within: Duration = .seconds(20)) async -> Bool {
            let deadline = ContinuousClock.now + within
            while ContinuousClock.now < deadline {
                if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                    return true
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
            return false
        }

        /// Kills whatever ffmpeg is writing `output`, the way anything outside the app would.
        private func kill(writingTo output: URL) {
            let process = Process()
            process.executableURL = URL(filePath: "/usr/bin/pkill")
            process.arguments = ["-9", "-f", output.path(percentEncoded: false)]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        }

        /// Whether an ffmpeg has picked the conversion up and is writing `output`.
        ///
        /// Waited for so the cancellation below has a running child to reach.
        private func started(writingTo output: URL, within: Duration = .seconds(20)) async -> Bool {
            let deadline = ContinuousClock.now + within
            while ContinuousClock.now < deadline {
                if isRunning(writingTo: output) { return true }
                try? await Task.sleep(for: .milliseconds(50))
            }
            return false
        }

        /// Whether no ffmpeg is writing `output` any more, allowing a moment for one that has been
        /// signalled to finish going.
        ///
        /// A single look would be asking whether it had gone at the instant it was told to, which is
        /// a question about scheduling rather than about whether the conversion cleans up after
        /// itself. Seconds would be a leak; a beat is a process exiting.
        private func stopped(writingTo output: URL) async -> Bool {
            for _ in 0..<20 {
                if !isRunning(writingTo: output) { return true }
                try? await Task.sleep(for: .milliseconds(100))
            }
            return false
        }

        /// Whether any ffmpeg is still writing `output`, matched on the full output path since every
        /// other part of the command line is shared with any other ffmpeg on the machine.
        private func isRunning(writingTo output: URL) -> Bool {
            let process = Process()
            process.executableURL = URL(filePath: "/usr/bin/pgrep")
            process.arguments = ["-f", output.path(percentEncoded: false)]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        }
    }
}

/// Collects the progress callbacks, which arrive on Foundation's reader queue.
private final class Fractions: @unchecked Sendable {
    private let lock = NSLock()
    private var fractions: [Double] = []

    func append(_ fraction: Double) {
        lock.withLock { fractions.append(fraction) }
    }

    var value: [Double] {
        lock.withLock { fractions }
    }
}
