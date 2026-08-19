//
//  ConversionCleanupTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

extension ConversionSuites {
    /// What a conversion leaves on disk when the app is asked to quit while it is running.
    ///
    /// A task is not cancelled by the process exiting, and a child is not killed by its parent
    /// going, so without this the ffmpeg behind a conversion carries on encoding into a file beside
    /// the user's film that nothing is left to move or delete.
    @MainActor
    @Suite(.serialized)
    struct ConversionCleanupTests {

        private func makeDirectory() throws -> URL {
            let directory = URL.cachesDirectory.appending(
                path: "FrontRowCleanup-\(UUID().uuidString)")
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            return directory
        }

        private func makeWorkingFile(in directory: URL) throws -> URL {
            let working = directory.appending(path: "The Film.mp4.frconverting")
            try Data(repeating: 0, count: 4096).write(to: working)
            return working
        }

        /// The half film goes with the conversion that was writing it.
        @Test(.timeLimit(.minutes(1)))
        func stoppingAConversionDeletesWhatItHadWritten() throws {
            let directory = try makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let working = try makeWorkingFile(in: directory)

            MediaConversion.stop(
                MediaConversion.ActiveConversion(task: Task {}, workingURL: working))

            #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path()).isEmpty)
        }

        /// Stopping has to reach ffmpeg too, which it does by cancelling the task the conversion
        /// runs in - that is what `MediaRemuxer` hangs its termination handler on.
        @Test(.timeLimit(.minutes(1)))
        func stoppingAConversionCancelsItsTask() async throws {
            let directory = try makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let working = try makeWorkingFile(in: directory)

            let cancelled = Cancellation()
            let task = Task {
                try? await Task.sleep(for: .seconds(60))
                cancelled.record(Task.isCancelled)
            }

            MediaConversion.stop(
                MediaConversion.ActiveConversion(task: task, workingURL: working))
            await task.value

            #expect(cancelled.value == true)
        }

        /// The usual case, since the conversion's own tidying up normally wins the race - stopping
        /// has to be able to arrive second without complaining.
        @Test(.timeLimit(.minutes(1)))
        func stoppingAConversionWhoseFileIsAlreadyGoneIsHarmless() throws {
            let directory = try makeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }

            MediaConversion.stop(
                MediaConversion.ActiveConversion(
                    task: Task {},
                    workingURL: directory.appending(path: "already gone.mp4.frconverting")
                )
            )

            #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path()).isEmpty)
        }

        /// Quitting is overwhelmingly not done mid-conversion, and that path has to be quiet.
        @Test(.timeLimit(.minutes(1)))
        func quittingWithNothingConvertingDoesNothing() {
            MediaConversion.stopConversionForTermination()

            #expect(MediaConversion.activeConversion == nil)
        }
    }
}

/// Records whether a task saw itself cancelled, from outside the task.
private final class Cancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var wasCancelled: Bool?

    func record(_ isCancelled: Bool) {
        lock.withLock { wasCancelled = isCancelled }
    }

    var value: Bool? {
        lock.withLock { wasCancelled }
    }
}
