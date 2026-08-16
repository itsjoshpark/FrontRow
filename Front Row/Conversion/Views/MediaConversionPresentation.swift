//
//  MediaConversionPresentation.swift
//  Front Row
//
//  Created by Joshua Park on 8/15/26.
//

import SwiftUI

extension View {
    /// Applies the conversion flow's alerts. Apply once per window scene.
    ///
    /// The progress sheet isn't here: it's an `NSAlert` attached to the window by
    /// `ConversionProgressSheet`, not a SwiftUI presentation.
    func mediaConversionPresentation(in scene: AlertScene) -> some View {
        remuxAlert(in: scene)
    }
}
