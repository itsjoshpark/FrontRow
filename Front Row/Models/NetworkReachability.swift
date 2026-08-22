//
//  NetworkReachability.swift
//  Front Row
//
//  Created by Joshua Park on 8/21/26.
//

import Network

/// Wraps the machine's network path so a remote file that's genuinely gone can be told apart from
/// one nothing could reach, and so tests can simulate pulling the plug.
protocol NetworkReachabilityProviding: Sendable {
    /// Whether this Mac has a route off it right now.
    func isConnected() async -> Bool
}

/// The real `NetworkReachabilityProviding`.
///
/// A monitor is started for the question and cancelled with the answer rather than kept running,
/// since the only thing that asks is an open that has already failed - rare enough that a live
/// copy would cost more than it saves, and a fresh path is always the correct one.
///
/// Only an outright unsatisfied path counts as disconnected. A path that needs bringing up, or one
/// that hasn't arrived within `timeout`, reads as connected: telling users they're offline when
/// they aren't is the worse of the two mistakes, and it leaves them doubting a file that is fine.
struct NetworkReachability: NetworkReachabilityProviding {

    static let shared = NetworkReachability()

    /// How long to wait for a first path before assuming there is one.
    private static let timeout = Duration.seconds(2)

    private init() {}

    func isConnected() async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                let monitor = NWPathMonitor()
                defer { monitor.cancel() }

                for await path in monitor {
                    return path.status != .unsatisfied
                }
                return true
            }
            group.addTask {
                try? await Task.sleep(for: Self.timeout)
                return true
            }

            let isConnected = await group.next() ?? true
            group.cancelAll()
            return isConnected
        }
    }
}
