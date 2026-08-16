//
//  InspectorGrid.swift
//  Front Row
//
//  Created by Joshua Park on 8/8/26.
//

import SwiftUI

/// Wraps a tab's rows in the scrolling, evenly aligned column layout every tab shares.
struct InspectorGrid<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 6, verticalSpacing: 8) {
                content
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .textSelection(.enabled)
    }
}
