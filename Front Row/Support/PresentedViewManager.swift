//
//  PresentedViewManager.swift
//  Front Row
//
//  Created by Joshua Park on 3/19/24.
//

import SwiftUI

@MainActor
@Observable public final class PresentedViewManager {

    static let shared = PresentedViewManager()

    var isPresentingOpenURLView = false

    var isPresentingGoToTimeView = false

    var isPresenting: Bool {
        isPresentingOpenURLView || isPresentingGoToTimeView
    }
}
