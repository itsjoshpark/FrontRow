//
//  SoakUITests.swift
//  Front Row UI Tests
//

import XCTest

/// Long runs of the same thing, looking for what a single pass cannot show.
///
/// These take minutes rather than seconds, so they are in `Soak.xctestplan` and off the default
/// run. Nothing here asserts an absolute number: footprint depends on the machine and on what the
/// system felt like caching. What is asserted is that the end of a run is not heavier than the
/// start.
@MainActor
final class SoakUITests: FrontRowUITestCase {

    /// Cycles before sampling starts. The first file opened brings in fonts, localization tables,
    /// asset catalogs and the video decoder's plug-in - a fixed cost that would otherwise read as
    /// growth on the first few samples.
    private let warmUpCycles = 3

    private var executablePath: String {
        get throws { try applicationURL.appending(path: "Contents/MacOS/Front Row").path() }
    }

    /// Fifty files opened one after another, cycling through three shapes so each open replaces a
    /// differently sized item.
    ///
    /// Every open after the first tears the player window down and builds it again, and every one
    /// releases the previous asset, item and its subscriptions. Fifty is enough for anything held
    /// per open to show.
    func testOpeningFilesRepeatedlyDoesNotGrow() async throws {
        let sizes = [
            CGSize(width: 640, height: 360), .init(width: 480, height: 640),
            .init(width: 400, height: 400),
        ]
        var movies: [URL] = []
        for (index, size) in sizes.enumerated() {
            movies.append(
                try await MediaFixtures.makeMovie(
                    size: size, named: "soak\(index)", in: fixtures, seconds: 2, frameRate: 4))
        }

        try await measureCycles(count: 50) { cycle in
            let movie = movies[cycle % movies.count]
            try self.openInFinder(movie)
            _ = try self.playerWindow(for: movie)
        }
    }

    /// Thirty Inspector open-and-closes with a file playing underneath.
    ///
    /// A second window carrying its own observation of the play engine, torn down and rebuilt each
    /// time. If the panel's state is what keeps the window alive, this is where it shows.
    func testTogglingTheInspectorDoesNotGrow() async throws {
        let movie = try await MediaFixtures.makeMovie(
            size: CGSize(width: 640, height: 360), named: "inspector", in: fixtures,
            seconds: 30, frameRate: 2)

        try openInFinder(movie)
        _ = try playerWindow(for: movie)

        try await measureCycles(count: 30) { _ in
            self.app.typeKey("i", modifierFlags: .command)
            try await Task.sleep(for: .milliseconds(400))
            self.app.typeKey("i", modifierFlags: .command)
            try await Task.sleep(for: .milliseconds(400))
        }
    }

    // MARK: - Measuring

    /// Runs `body` `count` times, sampling the app after each, and fails if the run trends upward.
    private func measureCycles(
        count: Int,
        _ body: @MainActor @escaping (Int) async throws -> Void
    ) async throws {
        let path = try executablePath
        var trend = FootprintTrend()

        for cycle in 0..<(warmUpCycles + count) {
            try await body(cycle)

            guard cycle >= warmUpCycles else { continue }
            // Sampled a beat after the cycle so a release that lands on the next run loop turn is
            // not counted as still held.
            try await Task.sleep(for: .milliseconds(300))
            guard let sample = ProcessFootprint.sample(executablePath: path) else {
                XCTFail("Could not sample the app on cycle \(cycle) - is it still running?")
                return
            }
            trend.record(sample)
        }

        let summary = trend.description

        guard let resident = trend.residentGrowth, let descriptors = trend.descriptorGrowth else {
            XCTFail("Not enough samples to read a trend: \(summary)")
            return
        }

        // A quarter allows for the memory the system caches on the app's behalf and does not give
        // back promptly. Anything held per cycle over fifty cycles clears it easily.
        XCTAssertLessThan(
            resident, 0.25,
            "Resident memory grew \(Int(resident * 100))% across the run - \(summary)"
        )

        // Descriptors are not cached and not approximate: a handful of movement is the run's own
        // noise, and more than that is something not being closed.
        XCTAssertLessThan(
            descriptors, 8,
            "Open descriptors grew by \(Int(descriptors)) across the run - \(summary)"
        )

        print("soak: \(summary)")
    }
}
