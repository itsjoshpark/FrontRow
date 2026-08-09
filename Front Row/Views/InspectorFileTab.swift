//
//  InspectorFileTab.swift
//  Front Row
//
//  Created by Joshua Park on 8/8/26.
//

import SwiftUI

/// Where the media came from and what the container says about it, rather than what's encoded
/// inside it.
struct InspectorFileTab: View {
    let file: FileSummary

    /// The longest time the chapter column has to show, which every entry is padded to. A stream
    /// - or any asset that doesn't report a duration - falls back to the last chapter's start,
    /// since padding each entry to its own magnitude is what leaves the column ragged.
    private var chapterScale: TimeInterval {
        file.duration ?? file.chapters.map(\.start).max() ?? 0
    }

    var body: some View {
        InspectorForm {
            InspectorSectionHeader(
                title: Text("Location", comment: "Inspector section heading for a path or URL"),
                isFirst: true
            )
            GridRow {
                Text(
                    verbatim: file.isLocal
                        ? file.url.path(percentEncoded: false) : file.url.absoluteString
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .gridCellColumns(2)
            }

            InspectorSectionHeader(
                title: Text("File", comment: "The media file, as a section heading and a tab"))
            Group {
                InspectorRow(
                    label: Text("Size"), value: file.byteSize.map(MediaValueFormat.byteSize))
                InspectorRow(label: Text("Format"), value: file.containerName)
                InspectorRow(
                    label: Text("Duration"), value: file.duration.map(MediaValueFormat.duration))
                InspectorRow(
                    label: Text("Created"),
                    value: file.createdAt?.formatted(date: .abbreviated, time: .shortened))
                InspectorRow(
                    label: Text("Modified"),
                    value: file.modifiedAt?.formatted(date: .abbreviated, time: .shortened))
                InspectorRow(
                    label: Text("Chapters"), value: file.chapters.count.formatted(.number))
            }

            if !file.chapters.isEmpty {
                InspectorSectionHeader(
                    title: Text("Chapter List", comment: "Inspector section heading"))
                ForEach(file.chapters) { chapter in
                    InspectorChapterRow(
                        start: MediaValueFormat.position(chapter.start, in: chapterScale),
                        title: chapter.title
                    )
                }
            }

            if !file.metadata.isEmpty {
                InspectorSectionHeader(
                    title: Text("Metadata", comment: "Inspector section heading for embedded tags"))
                ForEach(file.metadata) { entry in
                    InspectorRow(label: Text(verbatim: entry.label), value: entry.value)
                }
            }
        }
    }
}
