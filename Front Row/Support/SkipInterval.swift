//
//  SkipInterval.swift
//  Front Row
//
//  Created by Joshua Park on 8/5/26.
//

import Foundation

/// How far the skip forward/backward controls jump.
///
/// A closed set rather than a loose `Int` because each interval names an SF Symbol
/// (`goforward.10` and friends). Only these four exist for both directions, so a value outside
/// them would leave the buttons unlabelled.
enum SkipInterval: Int, CaseIterable, Identifiable {
    case five = 5
    case ten = 10
    case fifteen = 15
    case thirty = 30

    var id: Int { rawValue }

    var seconds: TimeInterval { TimeInterval(rawValue) }

    var backwardSymbol: String { "gobackward.\(rawValue)" }

    var forwardSymbol: String { "goforward.\(rawValue)" }
}
