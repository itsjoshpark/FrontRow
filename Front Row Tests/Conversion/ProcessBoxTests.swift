//
//  ProcessBoxTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

/// Holding the running process so a cancellation arriving on another task can stop it.
///
/// The race this exists to close is narrow and fatal: terminating a `Process` that was never
/// started raises an Objective-C exception, which Swift cannot catch.
// Serialised: each test launches a real child and blocks on it, and they contend for the queues
// serving their pipes.
@Suite(.serialized)
struct ProcessBoxTests {

    private func makeSleep() -> Process {
        let process = Process()
        process.executableURL = URL(filePath: "/bin/sleep")
        process.arguments = ["120"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        return process
    }

    @Test
    func launchingReportsThatItStarted() throws {
        let box = ProcessBox()
        let process = makeSleep()
        defer { process.terminate() }

        #expect(try box.launch(process))
        #expect(process.isRunning)
        #expect(!box.wasCancelled)
    }

    /// Cancellation arriving first means nothing is launched at all - the caller is told so and
    /// leaves without a child to wait for.
    @Test
    func cancellingFirstMeansNothingLaunches() throws {
        let box = ProcessBox()
        box.cancel()

        let process = makeSleep()
        #expect(try box.launch(process) == false)
        #expect(!process.isRunning)
        #expect(box.wasCancelled)
    }

    @Test
    func cancellingAfterLaunchStopsTheProcess() throws {
        let box = ProcessBox()
        let process = makeSleep()

        #expect(try box.launch(process))
        box.cancel()
        process.waitUntilExit()

        #expect(!process.isRunning)
        #expect(box.wasCancelled)
    }

    /// Cancelling more than once is what a user does when nothing seems to happen. The second one
    /// must not reach a process that has already gone.
    @Test
    func cancellingTwiceIsHarmless() throws {
        let box = ProcessBox()
        let process = makeSleep()

        #expect(try box.launch(process))
        box.cancel()
        process.waitUntilExit()
        box.cancel()

        #expect(box.wasCancelled)
    }

    @Test
    func cancellingWithoutEverLaunchingIsHarmless() {
        let box = ProcessBox()
        box.cancel()
        box.cancel()

        #expect(box.wasCancelled)
    }

    /// Launch and cancel really do arrive from different threads - the conversion runs detached
    /// while the cancellation comes from the sheet on the main queue. Repeated so the interleaving
    /// varies rather than resting on one lucky ordering.
    @Test(.timeLimit(.minutes(1)))
    func launchingAndCancellingAtTheSameTimeIsSafe() async throws {
        for _ in 0..<25 {
            let box = ProcessBox()
            let process = makeSleep()

            async let launched: Bool? = Task.detached { try? box.launch(process) }.value
            async let cancelled: Void = Task.detached { box.cancel() }.value

            let didLaunch = await launched ?? false
            await cancelled

            #expect(box.wasCancelled)

            // Whichever order they arrived in, nothing is left running: either the launch was
            // refused, or the cancellation reached the child that started.
            if didLaunch {
                #expect(
                    await stopped(process),
                    "The process survived a cancellation that came in alongside its launch"
                )
            } else {
                #expect(!process.isRunning)
            }

            // Belt and braces - a lingering `sleep` would outlast the test run.
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
        }
    }

    /// Whether `process` finishes within a couple of seconds, rather than blocking on a child that
    /// never got the signal.
    private func stopped(_ process: Process) async -> Bool {
        for _ in 0..<40 {
            if !process.isRunning { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return !process.isRunning
    }
}
