//
//  ScriptedTool.swift
//  Front Row Tests
//

import Foundation

/// An executable written for one test, standing in for ffmpeg or ffprobe.
///
/// The process code is the part worth testing here - draining two pipes, waiting for exit,
/// terminating on cancellation - and none of that cares what the tool actually is. A script says
/// exactly what the child does, including the things a real ffmpeg only does on a bad day.
struct ScriptedTool {

    let url: URL

    /// This tool's own directory name, unique to it.
    ///
    /// What to look for when finding the running child from outside: the path in a process's
    /// arguments comes back as `/var/tmp/…` while the URL here says `/private/var/tmp/…`, so
    /// matching on the whole path finds nothing. The name appears in both.
    let name: String

    /// Written by the script once it has finished setting itself up.
    ///
    /// A tool only ignores a signal from the line after its `trap`, so a test that cancels has to
    /// know the trap is in place.
    let ready: URL

    /// Written by the test to release a tool waiting at `holdUntilReleased`.
    let released: URL

    private let root: URL

    /// Writes `body` as a shell script and makes it executable.
    init(_ body: String) throws {
        name = "FrontRowTool-\(UUID().uuidString)"
        root = URL(filePath: "/private/var/tmp").appending(path: name)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        ready = root.appending(path: "ready")
        released = root.appending(path: "released")
        url = root.appending(path: "tool.sh")
        try "#!/bin/sh\n\(body)\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: url.path(percentEncoded: false))
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - Ready-made behaviours

    /// Prints `text` and stops.
    static func printing(_ text: String) throws -> ScriptedTool {
        try ScriptedTool("printf '%s' '\(text)'")
    }

    /// Writes `bytes` bytes to standard error, then exits with `status`.
    ///
    /// Enough output to fill the pipe's buffer, which is what wedges a child whose parent is busy
    /// reading the other pipe.
    static func flooding(stderrBytes bytes: Int, exiting status: Int32 = 1) throws -> ScriptedTool {
        try ScriptedTool(
            """
            yes 'ffmpeg is unhappy about something and says so at length' \
                | head -c \(bytes) >&2
            exit \(status)
            """
        )
    }

    /// Ignores termination and keeps running, for cancellation that has to be insisted on.
    ///
    /// The `seconds` it stays up for start when the test releases it, not when it launches, so
    /// how long the test took to get there cannot eat into them.
    static func ignoringTermination(seconds: Int = 120) throws -> ScriptedTool {
        try ScriptedTool(
            """
            here=$(dirname "$0")
            trap '' TERM
            : > "$here/ready"
            waited=0
            while [ ! -f "$here/released" ] && [ "$waited" -lt 200 ]; do
                sleep 0.05
                waited=$((waited + 1))
            done
            sleep \(seconds)
            """
        )
    }

    /// Waits until the script reports it has set itself up, or gives up after `within`.
    ///
    /// A test that cancels has to know the child is up for the cancellation to reach it.
    func waitUntilReady(within: Duration = .seconds(10)) async -> Bool {
        let deadline = ContinuousClock.now + within
        while ContinuousClock.now < deadline {
            if FileManager.default.fileExists(atPath: ready.path(percentEncoded: false)) {
                return true
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return false
    }

    /// Lets a tool held at `ignoringTermination` get on with it.
    func release() throws {
        try Data().write(to: released)
    }

    /// Runs until it is stopped.
    ///
    /// Loops rather than sleeping once. A shell whose script ends in a single command replaces
    /// itself with that command, and the process then no longer carries the script's path - so a
    /// test looking for the tool by name would find nothing and call it stopped.
    static func sleeping(seconds: Int = 120) throws -> ScriptedTool {
        try ScriptedTool(
            """
            here=$(dirname "$0")
            : > "$here/ready"
            elapsed=0
            while [ "$elapsed" -lt \(seconds) ]; do
                sleep 1
                elapsed=$((elapsed + 1))
            done
            """
        )
    }

    /// Emits ffmpeg's `-progress` blocks for a file of `duration` seconds, then finishes.
    static func reportingProgress(
        duration: TimeInterval,
        steps: Int,
        thenExiting status: Int32 = 0
    ) throws -> ScriptedTool {
        let lines = (1...steps).map { step in
            let microseconds = Int(duration * 1_000_000 * Double(step) / Double(steps))
            return """
                printf 'frame=1\\nout_time_us=\(microseconds)\\n'
                """
        }
        return try ScriptedTool(
            """
            \(lines.joined(separator: "\n"))
            printf 'progress=end\\n'
            exit \(status)
            """
        )
    }
}
