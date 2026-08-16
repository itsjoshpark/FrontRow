//
//  PlayerControlColor.swift
//  Front Row
//
//  Created by Joshua Park on 3/25/24.
//

import SwiftUI

/// Tints for the controls bar, which sits on video rather than on a system background and so
/// can't take its colors from the current appearance.
enum PlayerControlColor {
    static let foreground = Color.white.opacity(0.7)
    static let disabled = Color(nsColor: .disabledControlTextColor)

    static func text(isEnabled: Bool) -> Color {
        isEnabled ? foreground : disabled
    }
}
