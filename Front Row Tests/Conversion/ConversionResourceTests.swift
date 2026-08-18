//
//  ConversionResourceTests.swift
//  Front Row Tests
//
//  Created by Joshua Park on 8/17/26.
//

import Foundation
import Testing

@testable import Front_Row

/// What a conversion leaves behind: child processes, and the descriptors behind its two pipes.
///
/// A leak here does not show as memory. It shows as an ffmpeg still encoding after the user
/// cancelled, or as an app that has quietly run out of descriptors some hours into a session.
// Serialised: each test launches a real child and waits for it. Several at once hold a thread
// apiece, and on a machine with few cores the queues serving the pipes stop being run - the child
// fills one, blocks writing to it, and the wait never ends.
@Suite(.serialized)
struct ConversionResourceTests {

    private let recipe = RemuxRecipe(
        videoIndex: 0,
        videoTag: "hvc1",
        audio: [],
        subtitleIndices: [],
        droppedSubtitles: []
    )

    private func makeRemuxer(_ tool: ScriptedTool) -> MediaRemuxer {
        MediaRemuxer(tools: FFmpegTools(ffmpeg: tool.url, ffprobe: tool.url))
    }

    private var input: URL { URL(filePath: "/private/var/tmp/in.mkv") }
    private var output: URL { URL(filePath: "/private/var/tmp/out.mp4") }

    // MARK: - Children

    /// A cancelled conversion leaves no ffmpeg behind.
    ///
    /// The one a user is most likely to hit: they change their mind, the sheet goes away, and the
    /// machine's fans say the conversion did not.
    @Test(.timeLimit(.minutes(1)))
    func cancellingLeavesNoProcessRunning() async throws {
        let tool = try ScriptedTool.sleeping(seconds: 120)
        defer { tool.remove() }
        let remuxer = makeRemuxer(tool)

        let task = Task {
            try await remuxer.remux(
                input: input, output: output, recipe: recipe, duration: 10
            ) { _ in }
        }

        try await Task.sleep(for: .milliseconds(400))
        #expect(isRunning(tool), "The tool never started, so there was nothing to cancel")

        task.cancel()
        await #expect(throws: FFmpegError.cancelled) { try await task.value }

        #expect(!isRunning(tool), "The tool was still running after the conversion was cancelled")
    }

    /// A conversion that finishes on its own leaves nothing running either - the plainer half of
    /// the same question, and the one that would catch a tool being started twice.
    @Test(.timeLimit(.minutes(1)))
    func finishingLeavesNoProcessRunning() async throws {
        let tool = try ScriptedTool.reportingProgress(duration: 10, steps: 2)
        defer { tool.remove() }

        try await makeRemuxer(tool).remux(
            input: input, output: output, recipe: recipe, duration: 10
        ) { _ in }

        #expect(!isRunning(tool))
    }

    /// Cancellation waits for the tool to go, and a tool that ignores the signal keeps it waiting.
    ///
    /// `ProcessBox.cancel()` sends SIGTERM and `remux` then blocks in `waitUntilExit()`, so how
    /// long a cancellation takes is the child's decision. ffmpeg handles SIGTERM and leaves
    /// promptly, which is why this is a property worth knowing rather than a bug: a tool that did
    /// not would hold the conversion open for as long as it liked, with the sheet already gone.
    @Test(.timeLimit(.minutes(1)))
    func cancellingWaitsForAToolThatIgnoresTheSignal() async throws {
        let tool = try ScriptedTool.ignoringTermination(seconds: 3)
        defer { tool.remove() }
        let remuxer = makeRemuxer(tool)

        let task = Task {
            try await remuxer.remux(
                input: input, output: output, recipe: recipe, duration: 10
            ) { _ in }
        }

        try await Task.sleep(for: .milliseconds(400))
        let cancelledAt = ContinuousClock.now
        task.cancel()
        await #expect(throws: FFmpegError.cancelled) { try await task.value }

        #expect(
            cancelledAt.duration(to: .now) > .seconds(1),
            "The cancellation returned before the tool did, which would leave it running"
        )
        #expect(!isRunning(tool))
    }

    // MARK: - Descriptors

    /// Twenty conversions in a row, checking the pipes behind them are given back.
    ///
    /// Each run creates two `Pipe`s and hangs a readability handler on each. A handler left in
    /// place keeps its file handle alive, and the descriptor with it - a slow leak that shows up
    /// as a conversion failing to start long after the run that caused it.
    @Test(.timeLimit(.minutes(2)))
    func repeatedConversionsGiveTheirPipesBack() async throws {
        let tool = try ScriptedTool.reportingProgress(duration: 10, steps: 2)
        defer { tool.remove() }
        let remuxer = makeRemuxer(tool)

        // One first, so the descriptors any framework opens on the way through are already open
        // when the baseline is taken.
        try await remuxer.remux(input: input, output: output, recipe: recipe, duration: 10) { _ in }
        let baseline = await settledDescriptorCount()

        for _ in 0..<20 {
            try await remuxer.remux(
                input: input, output: output, recipe: recipe, duration: 10
            ) { _ in }
        }

        let growth = await settledDescriptorCount() - baseline
        #expect(growth <= 4, "Twenty conversions left \(growth) descriptors open")
    }

    /// The same over failures, which take a different path out - the error is read to the end and
    /// thrown rather than returned.
    @Test(.timeLimit(.minutes(2)))
    func repeatedFailuresGiveTheirPipesBack() async throws {
        let tool = try ScriptedTool.flooding(stderrBytes: 20_000)
        defer { tool.remove() }
        let remuxer = makeRemuxer(tool)

        try? await remuxer.remux(input: input, output: output, recipe: recipe, duration: 10) { _ in
        }
        let baseline = await settledDescriptorCount()

        for _ in 0..<20 {
            try? await remuxer.remux(
                input: input, output: output, recipe: recipe, duration: 10
            ) { _ in }
        }

        let growth = await settledDescriptorCount() - baseline
        #expect(growth <= 4, "Twenty failed conversions left \(growth) descriptors open")
    }

    /// `ExternalProcess` is the other user of the same pattern, for the tools that answer once and
    /// stop rather than reporting as they go.
    @Test(.timeLimit(.minutes(2)))
    func repeatedProbesGiveTheirPipesBack() async throws {
        let tool = try ScriptedTool.printing("{}")
        defer { tool.remove() }

        _ = try await ExternalProcess.run(tool.url, arguments: [])
        let baseline = await settledDescriptorCount()

        for _ in 0..<20 {
            _ = try await ExternalProcess.run(tool.url, arguments: [])
        }

        let growth = await settledDescriptorCount() - baseline
        #expect(growth <= 4, "Twenty probes left \(growth) descriptors open")
    }

    // MARK: - Looking from outside

    /// Whether any process is running `tool`, the child included.
    ///
    /// Matched on the tool's name rather than its path: a process reports its arguments with
    /// `/var/tmp/…` where the URL says `/private/var/tmp/…`, and the full path then matches
    /// nothing at all - which would read as "no orphan" and pass.
    private func isRunning(_ tool: ScriptedTool) -> Bool {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/pgrep")
        process.arguments = ["-f", tool.name]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    /// The lowest descriptor count seen over a moment, which is the one that means anything here.
    ///
    /// The count is for the whole test host, and the other suites run alongside this one - their
    /// pipes and sockets open and close under the sample. A descriptor that is leaked stays open
    /// through every sample; one that belongs to a neighbour does not.
    private func settledDescriptorCount() async -> Int {
        var lowest = Int.max
        for _ in 0..<5 {
            lowest = min(lowest, openDescriptorCount())
            try? await Task.sleep(for: .milliseconds(60))
        }
        return lowest
    }

    /// How many descriptors this process holds open, counted rather than listed - `lsof` on your
    /// own process costs more than asking the kernel about each slot in turn.
    private func openDescriptorCount() -> Int {
        (0..<getdtablesize()).count { fcntl($0, F_GETFD) != -1 }
    }
}
