//
//  ProcessFootprint.swift
//  Front Row UI Tests
//

import Foundation

/// What the app is holding, sampled from outside it.
///
/// A UI test drives the app from another process, so nothing inside it can be asked. These are the
/// two numbers visible from here that answer "is this run growing": resident memory, and open file
/// descriptors - the sharper of the two for the conversion path, which opens two pipes per run.
struct ProcessFootprint {

    /// Resident set size in kilobytes.
    let residentKilobytes: Int

    /// Everything `lsof` lists for the process: files, sockets, pipes, mapped regions.
    let openDescriptors: Int

    /// Samples the process running `executablePath`, or `nil` if it isn't running.
    static func sample(executablePath: String) -> ProcessFootprint? {
        guard let pid = processIdentifier(forExecutable: executablePath) else { return nil }

        let resident = Int(output(of: "/bin/ps", ["-o", "rss=", "-p", pid]) ?? "") ?? 0
        // -n and -P skip host and port name lookups, which on a process holding network
        // connections cost seconds per sample and add up over a fifty-cycle run.
        let descriptors = (output(of: "/usr/sbin/lsof", ["-n", "-P", "-p", pid]) ?? "")
            .split(separator: "\n")
            .count

        // A header line and nothing else means lsof was refused rather than that nothing is open.
        guard resident > 0, descriptors > 1 else { return nil }

        return ProcessFootprint(residentKilobytes: resident, openDescriptors: descriptors - 1)
    }

    private static func processIdentifier(forExecutable path: String) -> String? {
        guard let listed = output(of: "/usr/bin/pgrep", ["-f", path]) else { return nil }
        return listed.split(separator: "\n").first.map(String.init)
    }

    /// Runs `tool` and returns its trimmed standard output, or `nil` if it wrote nothing.
    private static func output(of tool: String, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(filePath: tool)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let text = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

/// A run of samples, read as a trend rather than as numbers.
///
/// Absolute footprint says nothing useful - it depends on the machine, the video, and what the
/// system decided to cache. What a soak can say is whether the end of the run is heavier than the
/// start, so the samples are compared in thirds and the middle discarded.
struct FootprintTrend {

    private(set) var samples: [ProcessFootprint] = []

    mutating func record(_ sample: ProcessFootprint) {
        samples.append(sample)
    }

    /// Mean resident memory over the first and last third of the run.
    var residentThirds: (first: Double, last: Double)? {
        thirds(of: samples.map { Double($0.residentKilobytes) })
    }

    var descriptorThirds: (first: Double, last: Double)? {
        thirds(of: samples.map { Double($0.openDescriptors) })
    }

    /// How much heavier the last third is than the first, as a fraction. Negative means lighter.
    var residentGrowth: Double? {
        guard let (first, last) = residentThirds, first > 0 else { return nil }
        return (last - first) / first
    }

    var descriptorGrowth: Double? {
        guard let (first, last) = descriptorThirds else { return nil }
        return last - first
    }

    private func thirds(of values: [Double]) -> (first: Double, last: Double)? {
        let size = values.count / 3
        guard size > 0 else { return nil }
        let first = values.prefix(size)
        let last = values.suffix(size)
        return (first.reduce(0, +) / Double(size), last.reduce(0, +) / Double(size))
    }

    var description: String {
        guard let resident = residentThirds, let descriptors = descriptorThirds else {
            return "not enough samples"
        }
        return String(
            format: "resident %.0fK -> %.0fK, descriptors %.1f -> %.1f over %d samples",
            resident.first, resident.last, descriptors.first, descriptors.last, samples.count
        )
    }
}
