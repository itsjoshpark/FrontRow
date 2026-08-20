//
//  PresentationModel.swift
//  Front Row
//
//  Created by Joshua Park on 3/19/24.
//

import SwiftUI

@MainActor
@Observable final class PresentationModel {

    static let shared = PresentationModel()

    var isPresentingOpenURLView = false

    var isPresentingGoToTimeView = false

    /// A recent file that could not be opened.
    ///
    /// Raised through `raise(_:)` and cleared through `dismissUnopenableRecentFile()`.
    private(set) var unopenableRecentFile: UnopenableRecentFile?

    /// Whatever stage of a conversion is asking the user something.
    ///
    /// Raised through `raise(_:)` and cleared through `dismissRemuxAlert()`.
    private(set) var remuxAlert: RemuxAlert?

    /// Whether a file is being checked over before anything is offered about it.
    ///
    /// Holds the slot below for the same reason a running conversion does: the check puts a sheet
    /// on the window a question would have to appear over, and a second file arriving mid-check
    /// would start a second ffprobe behind it.
    private(set) var isCheckingFile = false

    /// Whether a conversion is running. The sheet reporting on it belongs to AppKit, so this is
    /// only here to keep playback commands disabled while it's up - and to hold the slot below,
    /// since that sheet is on the window a question would have to appear over.
    private(set) var isConverting = false

    /// Whether the app is already occupied with a file.
    ///
    /// Both alerts are stacked on the same view in each scene, so between them they have one place
    /// to appear, and a conversion's sheet is sitting in it while one runs. A question raised into
    /// any of that is not a second alert - it is one alert wearing another's buttons, or one that
    /// is dropped and never answered.
    var isAskingAboutAFile: Bool {
        remuxAlert != nil || unopenableRecentFile != nil || isConverting || isCheckingFile
    }

    var isPresenting: Bool {
        isPresentingOpenURLView || isPresentingGoToTimeView || isAskingAboutAFile
    }

    /// Puts a conversion question to the user, and reports whether it got the floor.
    ///
    /// Refused rather than allowed to replace what is already there, and the refusing is the whole
    /// point. SwiftUI settles an alert's wording when it presents it but builds its buttons from
    /// whatever the value holds now, so swapping the value under a question already on screen draws
    /// one question's words above another's buttons - and the buttons are what the answer acts on.
    @discardableResult
    func raise(_ alert: RemuxAlert) -> Bool {
        guard !isAskingAboutAFile else { return false }
        remuxAlert = alert
        return true
    }

    /// The same for a recent file that wouldn't open, which shares the one place to appear.
    @discardableResult
    func raise(_ file: UnopenableRecentFile) -> Bool {
        guard !isAskingAboutAFile else { return false }
        unopenableRecentFile = file
        return true
    }

    /// Takes the conversion question down, if `scene` is the one holding it.
    ///
    /// Each scene applies its own modifier to the same app-wide value, so both are told when either
    /// is dismissed. Only the one that was presenting may clear it. Safe to state as a rule because
    /// a question cannot change scene once raised: the only moves this type allows are nothing to
    /// something and back again.
    func dismissRemuxAlert(in scene: AlertScene) {
        guard remuxAlert?.scene == scene else { return }
        remuxAlert = nil
    }

    /// The same for the recent-file question.
    func dismissUnopenableRecentFile(in scene: AlertScene) {
        guard unopenableRecentFile?.scene == scene else { return }
        unopenableRecentFile = nil
    }

    /// Marks a file as being checked over, which holds the slot until the check is done.
    func checkBegan() {
        isCheckingFile = true
    }

    func checkEnded() {
        isCheckingFile = false
    }

    /// Marks a conversion as running, which holds the slot until it is done.
    func conversionBegan() {
        isConverting = true
    }

    func conversionEnded() {
        isConverting = false
    }
}
