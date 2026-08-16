//
//  InspectorPlaceholder.swift
//  Front Row
//
//  Created by Joshua Park on 8/8/26.
//

import SwiftUI

/// Fills a tab that has nothing to describe, centred so it reads as a state rather than a missing
/// first row.
struct InspectorPlaceholder: View {
    let message: Text

    var body: some View {
        message
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
