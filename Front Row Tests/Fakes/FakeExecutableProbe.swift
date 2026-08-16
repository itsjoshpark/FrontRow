//
//  FakeExecutableProbe.swift
//  Front Row Tests
//

import Foundation

@testable import Front_Row

/// Reports only the paths it was given as executable, so tool discovery can be tested without
/// depending on what happens to be installed on the machine running the tests.
struct FakeExecutableProbe: ExecutableProbing {
    let executablePaths: Set<String>

    init(_ executablePaths: String...) {
        self.executablePaths = Set(executablePaths)
    }

    func isExecutable(atPath path: String) -> Bool {
        executablePaths.contains(path)
    }
}
