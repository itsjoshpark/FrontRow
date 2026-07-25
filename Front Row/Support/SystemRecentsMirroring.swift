//
//  SystemRecentsMirroring.swift
//  Front Row
//
//  Created by Joshua Park on 7/19/26.
//

import Foundation

/// The system's own recent-documents list, which the app's list is mirrored into so surfaces it
/// doesn't draw itself - the Dock menu, Finder's Open Recent - stay in sync.
///
/// Abstracted so tests don't reach the real list: it's global to the user, not to the process, so
/// exercising a store against it would clear and repopulate the developer's actual recents.
@MainActor
protocol SystemRecentsMirroring {

    /// The user's Recent Items preference, which caps how much history is kept.
    var maximumCount: Int { get }

    func note(_ url: URL)

    func clearAll()
}
