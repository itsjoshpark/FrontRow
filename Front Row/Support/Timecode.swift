//
//  Timecode.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import Foundation

/// Reads a typed timecode, independent of `AVPlayer` so it can be tested directly.
enum Timecode {

    /// Parses `h:mm:ss`, `m:ss`, or bare seconds into a position in seconds.
    ///
    /// Components are read right to left, so a shorter string means the smaller units. A
    /// component that isn't a number counts as zero, and only a string with nothing readable in
    /// it at all returns `nil`. The result isn't range-checked - whether it lands inside the file
    /// is the caller's to decide.
    static func parse(_ timecode: String) -> TimeInterval? {
        let components = Array(timecode.split(separator: ":").reversed())

        let hour = components.count > 2 ? Int(components[2]) : nil
        let minute = components.count > 1 ? Int(components[1]) : nil
        let second = components.isEmpty ? nil : Double(components[0])

        guard hour != nil || minute != nil || second != nil else { return nil }

        return TimeInterval((hour ?? 0) * 3600 + (minute ?? 0) * 60) + (second ?? 0)
    }
}

extension TimeInterval {
    /// Returns value as timecode string.
    /// - Parameter longestTime: Used to determine if hour should be displayed
    /// - Returns: 0:00 or 0:00:00
    ///
    func asTimecode(using longestTime: TimeInterval) -> String {
        let hasHour = (longestTime / 3600.0) > 1.0
        if hasHour {
            return Duration.seconds(self).formatted(
                .time(pattern: .hourMinuteSecond(padHourToLength: 0)))
        } else {
            return Duration.seconds(self).formatted(
                .time(pattern: .minuteSecond(padMinuteToLength: 2)))
        }
    }
}
