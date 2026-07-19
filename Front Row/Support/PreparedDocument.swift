//
//  PreparedDocument.swift
//  Front Row
//
//  Created by Joshua Park on 7/19/26.
//

import Foundation

/// Everything needed to play a file, resolved but not yet committed to the recents list.
///
/// Opening is two-phase because a file that turns out to be unplayable must leave no trace: adding
/// it to recents first would publish it to `NSDocumentController`, which has no API to retract a
/// single entry. Holding the grant here also keeps the previously playing file readable until its
/// replacement is known to be good.
struct PreparedDocument {

    let id: RecentDocument.ID

    /// The URL to actually play - the bookmark-resolved one for a tracked file, which is not
    /// necessarily the URL the caller asked for.
    let url: URL

    let bookmarkData: Data

    let savedPosition: TimeInterval?

    /// `nil` for a first-time URL, which already has ambient access from the open panel or drop.
    let access: ScopedAccess?
}
