//
//  MediaFileDrop.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import SwiftUI
import UniformTypeIdentifiers

extension View {
    /// Accepts drops of supported media files and opens the first one.
    func mediaFileDropDestination() -> some View {
        onDrop(
            of: [.fileURL],
            delegate: AnyDropDelegate(
                onValidate: { $0.hasItemsConforming(to: PlayEngine.supportedFileTypes) },
                onPerform: { info in
                    guard let provider = info.itemProviders(for: [.fileURL]).first else {
                        return false
                    }
                    provider.loadFileURL { url in
                        guard let url else { return }
                        Task { @MainActor in
                            await openFileAndPresent(url: url)
                        }
                    }
                    return true
                }
            )
        )
    }
}

/// A `DropDelegate` built from closures, which is what lets a drop be rejected before it happens -
/// `onDrop(of:isTargeted:perform:)` can only filter by type identifier, and every media file is a
/// file URL.
struct AnyDropDelegate: DropDelegate {
    var onValidate: ((DropInfo) -> Bool)?
    let onPerform: (DropInfo) -> Bool

    func performDrop(info: DropInfo) -> Bool {
        onPerform(info)
    }

    func validateDrop(info: DropInfo) -> Bool {
        onValidate?(info) ?? true
    }
}

extension NSItemProvider {
    /// Load a file URL from the item provider.
    func loadFileURL(completion: @escaping @Sendable (URL?) -> Void) {
        loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
            guard let data = data as? Data,
                let url = URL(dataRepresentation: data, relativeTo: nil)
            else {
                completion(nil)
                return
            }
            completion(url)
        }
    }
}
