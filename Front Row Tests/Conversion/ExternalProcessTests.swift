//
//  ExternalProcessTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

extension ConversionSuites {
    /// Running a command-line tool and collecting what it printed.
    ///
    /// The interesting cases are the ones a real ffprobe only reaches when something is wrong, which
    /// is exactly when the app most needs the output it failed to collect.
    struct ExternalProcessTests {

        /// A tool that will never answer must not hold the file-opening path open for good.
        @Test(.timeLimit(.minutes(1)))
        func aToolThatOutstaysItsDeadlineIsStopped() async throws {
            let tool = try ScriptedTool.sleeping()
            defer { tool.remove() }

            let started = ContinuousClock.now
            await #expect(throws: FFmpegError.timedOut) {
                try await ExternalProcess.run(
                    tool.url, arguments: [], timeout: .milliseconds(300))
            }

            #expect(ContinuousClock.now - started < .seconds(20))
        }

        /// The deadline must not cut short a tool that is merely being asked for a lot.
        @Test(.timeLimit(.minutes(1)))
        func aToolThatAnswersWithinItsDeadlineIsLeftAlone() async throws {
            let tool = try ScriptedTool.printing("done")
            defer { tool.remove() }

            let output = try await ExternalProcess.run(
                tool.url, arguments: [], timeout: .seconds(30))

            #expect(output.didSucceed)
            #expect(String(decoding: output.standardOutput, as: UTF8.self) == "done")
        }

        @Test
        func standardOutputComesBack() async throws {
            let tool = try ScriptedTool.printing("{\"streams\":[]}")
            defer { tool.remove() }

            let output = try await ExternalProcess.run(
                tool.url, arguments: [], timeout: .seconds(30))

            #expect(output.didSucceed)
            #expect(String(decoding: output.standardOutput, as: UTF8.self) == "{\"streams\":[]}")
        }

        @Test
        func aFailingToolReportsItsStatus() async throws {
            let tool = try ScriptedTool("exit 3")
            defer { tool.remove() }

            let output = try await ExternalProcess.run(
                tool.url, arguments: [], timeout: .seconds(30))

            #expect(!output.didSucceed)
            #expect(output.terminationStatus == 3)
        }

        /// The case the error pipe is drained as it arrives for. A child that writes more than the
        /// pipe's buffer holds blocks until someone reads it - and this side is blocked reading
        /// standard output, so neither moves and the app hangs.
        ///
        /// A megabyte is far past the 64K a pipe buffers.
        @Test(.timeLimit(.minutes(1)))
        func aToolThatFloodsStandardErrorStillFinishes() async throws {
            let tool = try ScriptedTool.flooding(stderrBytes: 1_000_000)
            defer { tool.remove() }

            let output = try await ExternalProcess.run(
                tool.url, arguments: [], timeout: .seconds(30))

            #expect(output.terminationStatus == 1)
            #expect(output.standardError.count >= 1_000_000)
        }

        /// What ffprobe prints on its way out has to survive the race between the reader queue and
        /// the process exiting, since the message is the whole reason the failure is being read.
        @Test(.timeLimit(.minutes(1)))
        func aToolThatComplainsAndExitsImmediatelyIsStillHeard() async throws {
            let tool = try ScriptedTool(
                """
                printf 'Invalid data found when processing input\\n' >&2
                exit 1
                """
            )
            defer { tool.remove() }

            let output = try await ExternalProcess.run(
                tool.url, arguments: [], timeout: .seconds(30))

            #expect(output.standardError.contains("Invalid data found"))
        }

        @Test
        func argumentsReachTheTool() async throws {
            let tool = try ScriptedTool("printf '%s' \"$2\"")
            defer { tool.remove() }

            let output = try await ExternalProcess.run(
                tool.url, arguments: ["-i", "film.mkv"], timeout: .seconds(30))

            #expect(String(decoding: output.standardOutput, as: UTF8.self) == "film.mkv")
        }

        /// A tool that cannot be run is thrown out of, rather than reported as a tool that ran and
        /// failed - those mean different things to the caller.
        @Test
        func aMissingToolThrows() async throws {
            let missing = URL(
                filePath: "/private/var/tmp/front-row-no-such-tool-\(UUID().uuidString)")

            await #expect(throws: (any Error).self) {
                try await ExternalProcess.run(missing, arguments: [], timeout: .seconds(30))
            }
        }
    }
}
