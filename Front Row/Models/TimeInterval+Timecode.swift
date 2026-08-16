//
//  TimeInterval+Timecode.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import Foundation

extension TimeInterval {
    /// Returns value as timecode string.
    /// - Parameter longestTime: Used to determine if hour should be displayed
    /// - Returns: 0:00 or 0:00:00
    ///
    func asTimecode(using longestTime: TimeInterval) -> String {
        let hasHour = longestTime >= 3600.0
        if hasHour {
            return Duration.seconds(self).formatted(
                .time(pattern: .hourMinuteSecond(padHourToLength: 0)))
        } else {
            return Duration.seconds(self).formatted(
                .time(pattern: .minuteSecond(padMinuteToLength: 2)))
        }
    }
}
