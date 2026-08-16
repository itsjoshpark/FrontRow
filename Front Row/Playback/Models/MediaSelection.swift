//
//  MediaSelection.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import AVFoundation

extension AVMediaSelectionOption {
    /// Provides a stable identifier for the option.
    var stableID: String {
        let dict = propertyList() as? NSDictionary
        guard let dict, let id = dict.value(forKey: "MediaSelectionOptionsPersistentID") as? Int
        else {
            return displayName
        }
        guard
            let nonForcedSubtitles = dict.value(
                forKey: "MediaSelectionOptionsDisplaysNonForcedSubtitles") as? Int
        else {
            return "\(id)"
        }
        return "\(id)\(nonForcedSubtitles)"
    }
}

extension AVMediaSelectionGroup {
    /// The subtitle options worth offering as a choice.
    ///
    /// Forced-only tracks are left out. They exist to be switched on automatically for
    /// foreign-language passages inside a track the viewer already chose, not to be picked by
    /// hand.
    var selectableSubtitleOptions: [AVMediaSelectionOption] {
        options.filter { !$0.hasMediaCharacteristic(.containsOnlyForcedSubtitles) }
    }
}
