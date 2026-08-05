//
//  KeyValueObservation.swift
//  Front Row
//
//  Created by Joshua Park on 8/5/26.
//

import Foundation

/// Bridges a KVO-observed property into a buffered async sequence.
///
/// `publisher(for:).values` looks like the natural way to do this and isn't. A KVO publisher
/// emits whenever the property changes, with no regard for demand, and `AsyncPublisher` discards
/// anything that arrives while the consumer isn't currently waiting on it. An `AVPlayerItem` that
/// becomes ready during that gap loses its readiness for good - and paired with a duplicate
/// filter, the same value is never sent again, so the player stays loading forever.
///
/// Buffering every change here means a value can arrive late, but never go missing.
func observedValues<Object: NSObject, Value: Sendable>(
    of object: Object,
    at keyPath: KeyPath<Object, Value>
) -> AsyncStream<Value> {
    AsyncStream(bufferingPolicy: .unbounded) { continuation in
        // Seeded from here rather than through the `.initial` option, so the current value is
        // read in the caller's context instead of KVO's.
        continuation.yield(object[keyPath: keyPath])

        let observation = object.observe(keyPath, options: [.new]) { _, change in
            guard let value = change.newValue else { return }
            continuation.yield(value)
        }

        continuation.onTermination = { _ in
            observation.invalidate()
        }
    }
}
