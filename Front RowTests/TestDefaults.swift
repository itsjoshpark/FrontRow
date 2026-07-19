//
//  TestDefaults.swift
//  Front RowTests
//
//  Created by Joshua Park on 7/19/26.
//

import Foundation

/// An isolated `UserDefaults` suite that erases itself when the test that owns it goes out of
/// scope, so tests never read or write the app's real preferences.
final class TestDefaults {

    let suite: UserDefaults

    private let name: String

    init() {
        name = "dev.joshuapark.FrontRow.tests.\(UUID().uuidString)"
        suite = UserDefaults(suiteName: name)!
    }

    deinit {
        suite.removePersistentDomain(forName: name)
    }
}
