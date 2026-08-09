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
            InspectorFieldName(name: label)

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
            InspectorFieldName(name: label)

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

/// One entry in the chapter list. The time takes the field-name column but is a value rather than
/// a name, so it goes without the trailing colon.
struct InspectorChapterRow: View {
    let start: String
    let title: String?

    var body: some View {
        GridRow {
            Text(verbatim: start)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)

            if let title {
                Text(verbatim: title)
                    .gridColumnAlignment(.leading)
            } else {
                Text("Untitled", comment: "A chapter with no name of its own")
                    .foregroundStyle(.tertiary)
                    .gridColumnAlignment(.leading)
            }
        }
    }
}

/// Names the field in the row beside it. The colon marks it as a label rather than another value,
/// which matters once the two columns sit close together.
private struct InspectorFieldName: View {
    let name: Text

    var body: some View {
        (name + Text(verbatim: ":"))
            .fontWeight(.semibold)
            .gridColumnAlignment(.trailing)
    }
}

/// Names the group of rows below it, spanning both columns so it reads as a heading rather than
/// as another value. Every heading but the first is preceded by a rule, which is what separates
/// one group of fields from the next now that the rows sit close together.
struct InspectorSectionHeader: View {
    let title: Text
    var isFirst = false

    var body: some View {
        GridRow {
            VStack(spacing: 8) {
                if !isFirst {
                    Divider()
                }

                title
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, isFirst ? 0 : 10)
            .padding(.bottom, 4)
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
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 2) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .textSelection(.enabled)
    }
}
