//
//  FakeNetworkReachability.swift
//  Front Row Tests
//

import Foundation

@testable import Front_Row

/// Lets a test pull the plug without touching the machine's real network.
struct FakeNetworkReachability: NetworkReachabilityProviding {

    var connected: Bool

    func isConnected() async -> Bool { connected }
}
