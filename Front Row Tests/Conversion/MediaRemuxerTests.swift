//
//  MediaRemuxerTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

/// Running the conversion: reporting progress, surviving a chatty failure, and stopping when the
/// user says so.
///
/// A scripted tool stands in for ffmpeg. What is under test is the process handling around it -
/// two pipes read at once, a wait for exit, and a cancellation that has to reach a child that may
/// not have started yet.
// Serialised: each test launches a real child and blocks on it, and they contend for the queues
// serving their pipes.
@Suite(.serialized)
struct MediaRemuxerTests {

    private let recipe = RemuxRecipe(
        videoIndex: 0,
        videoTag: "hvc1",
        audio: [PlannedAudio(index: 1, codecName: "ac3", channels: 6, transcodes: true)],
        subtitleIndices: [],
        droppedSubtitles: []
    )

    private func makeRemuxer(_ tool: ScriptedTool) -> MediaRemuxer {
        MediaRemuxer(tools: FFmpegTools(ffmpeg: tool.url, ffprobe: tool.url))
    }

    private var input: URL { URL(filePath: "/private/var/tmp/in.mkv") }
    private var output: URL { URL(filePath: "/private/var/tmp/out.mp4") }

    // MARK: - Progress

    @Test(.timeLimit(.minutes(1)))
    func progressIsReportedAndEndsAtOne() async throws {
        let tool = try ScriptedTool.reportingProgress(duration: 100, steps: 4)
        defer { tool.remove() }

        let fractions = Fractions()
        try await makeRemuxer(tool).remux(
            input: input, output: output, recipe: recipe, duration: 100
        ) { fractions.append($0) }

        let reported = fractions.value
        #expect(reported.contains { abs($0 - 0.25) < 0.001 })
        #expect(reported.contains(1), "The conversion never reported that it had finished")

        // Not `last`. The reader handler runs on Foundation's queue, and one already dispatched
        // when the handler is cleared can deliver its line after the finishing 1 - so a progress
        // bar can take one step backwards at the very end. Nothing reported may exceed 1, which
        // is the part that would be wrong rather than untidy.
        #expect(reported.max() == 1)
    }

    /// ffprobe cannot always measure a duration. Without one there is no fraction to work out, so
    /// the run has to complete reporting nothing but the finish.
    @Test(.timeLimit(.minutes(1)))
    func aFileOfUnknownDurationStillCompletes() async throws {
        let tool = try ScriptedTool.reportingProgress(duration: 100, steps: 4)
        defer { tool.remove() }

        let fractions = Fractions()
        try await makeRemuxer(tool).remux(
            input: input, output: output, recipe: recipe, duration: nil
        ) { fractions.append($0) }

        #expect(fractions.value == [1])
    }

    // MARK: - Failure

    @Test(.timeLimit(.minutes(1)))
    func aFailingConversionCarriesWhatFfmpegSaid() async throws {
        let tool = try ScriptedTool(
            """
            printf 'Encoder (codec aac) not found\\n' >&2
            exit 1
            """
        )
        defer { tool.remove() }

        await #expect(throws: FFmpegError.self) {
            try await makeRemuxer(tool).remux(
                input: input, output: output, recipe: recipe, duration: 10
            ) { _ in }
        }

        do {
            try await makeRemuxer(tool).remux(
                input: input, output: output, recipe: recipe, duration: 10
            ) { _ in }
        } catch FFmpegError.conversionFailed(let message) {
            #expect(message.contains("Encoder (codec aac) not found"))
        }
    }

    /// The failure alert hides ffmpeg's output behind a disclosure and keeps it whole, so a
    /// complaint longer than a pipe's buffer has to arrive intact rather than deadlocking the run.
    @Test(.timeLimit(.minutes(1)))
    func aLongComplaintArrivesWhole() async throws {
        let tool = try ScriptedTool.flooding(stderrBytes: 500_000)
        defer { tool.remove() }

        do {
            try await makeRemuxer(tool).remux(
                input: input, output: output, recipe: recipe, duration: 10
            ) { _ in }
            Issue.record("A tool exiting non-zero should have thrown")
        } catch FFmpegError.conversionFailed(let message) {
            #expect(message.count >= 400_000)
        }
    }

    // MARK: - Cancellation

    @Test(.timeLimit(.minutes(1)))
    func cancellingStopsTheConversion() async throws {
        let tool = try ScriptedTool.sleeping(seconds: 120)
        defer { tool.remove() }
        let remuxer = makeRemuxer(tool)

        let task = Task {
            try await remuxer.remux(
                input: input, output: output, recipe: recipe, duration: 10
            ) { _ in }
        }

        // Up first, so cancellation has something to terminate rather than only setting the flag.
        #expect(await tool.waitUntilReady(), "The tool never started, so there was nothing to stop")
        task.cancel()

        await #expect(throws: FFmpegError.cancelled) { try await task.value }
    }

    /// Cancelling before the child is launched must not terminate a process that isn't running.
    /// `Process.terminate()` on one that never started raises an Objective-C exception, which
    /// Swift cannot catch - it would take the app down rather than stop a conversion.
    @Test(.timeLimit(.minutes(1)))
    func cancellingBeforeTheToolStartsThrowsRatherThanCrashes() async throws {
        let tool = try ScriptedTool.sleeping(seconds: 120)
        defer { tool.remove() }
        let remuxer = makeRemuxer(tool)

        let task = Task {
            try await remuxer.remux(
                input: input, output: output, recipe: recipe, duration: 10
            ) { _ in }
        }
        task.cancel()

        await #expect(throws: FFmpegError.cancelled) { try await task.value }
    }

    /// A cancelled run reports cancellation whatever the child's exit status turned out to be -
    /// a tool killed mid-write usually exits non-zero, and that is not a conversion failure to
    /// raise an alert about.
    @Test(.timeLimit(.minutes(2)))
    func aCancelledRunIsNotReportedAsAFailure() async throws {
        // Ready is reported after the trap is set, so a cancellation arriving the moment it
        // appears finds the handler in place.
        let tool = try ScriptedTool(
            """
            here=$(dirname "$0")
            trap 'exit 9' TERM
            : > "$here/ready"
            sleep 120
            """
        )
        defer { tool.remove() }
        let remuxer = makeRemuxer(tool)

        let task = Task {
            try await remuxer.remux(
                input: input, output: output, recipe: recipe, duration: 10
            ) { _ in }
        }

        #expect(await tool.waitUntilReady(), "The tool never started, so there was nothing to stop")
        task.cancel()

        await #expect(throws: FFmpegError.cancelled) { try await task.value }
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
