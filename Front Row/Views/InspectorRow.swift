//
//  InspectorRow.swift
//  Front Row
//
//  Created by Joshua Park on 8/8/26.
//

import SwiftUI

/// One label/value line in the Inspector.
///
/// A `nil` value reads "N/A" and is dimmed, marking a field the file simply doesn't carry rather
/// than leaving a blank the reader has to interpret.
struct InspectorRow: View {
    let label: Text
    let value: String?

    var body: some View {
        GridRow {
            label
                .fontWeight(.semibold)
                .gridColumnAlignment(.trailing)

            if let value {
                Text(verbatim: value)
                    .gridColumnAlignment(.leading)
            } else {
                Text("N/A", comment: "Inspector value for a field the file doesn't provide")
                    .foregroundStyle(.tertiary)
                    .gridColumnAlignment(.leading)
            }
        }
    }
}

/// A row of on/off properties shown side by side, with the ones that don't apply dimmed rather
/// than hidden - so the same set is always in the same place from track to track.
struct InspectorFlagsRow: View {
    let label: Text
    let flags: [(name: Text, isOn: Bool)]

    var body: some View {
        GridRow {
            label
                .fontWeight(.semibold)
                .gridColumnAlignment(.trailing)

            HStack(spacing: 10) {
                ForEach(flags.indices, id: \.self) { index in
                    flags[index].name
                        .foregroundStyle(flags[index].isOn ? .primary : .tertiary)
                }
            }
            .gridColumnAlignment(.leading)
        }
    }
}

/// Names the group of rows below it, spanning both columns so it reads as a heading rather than
/// as another value.
struct InspectorSectionHeader: View {
    let title: Text
    var isFirst = false

    var body: some View {
        GridRow {
            title
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, isFirst ? 0 : 14)
                .gridCellColumns(2)
        }
    }
}

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

/// Wraps a tab's rows in the scrolling, evenly aligned column layout every tab shares.
struct InspectorForm<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 7) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .textSelection(.enabled)
    }
}
