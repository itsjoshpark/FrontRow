//
//  PlaybackSpeed.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import Foundation

extension Float {
    static func isApproxEqual(lhs: Float, rhs: Float) -> Bool {
        abs(lhs - rhs) < Float.ulpOfOne
    }
}
