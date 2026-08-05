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
    at keyPath: any KeyPath<Object, Value> & Sendable
) -> AsyncStream<Value> {
    AsyncStream(bufferingPolicy: .unbounded) { continuation in
        // Seeded from here rather than through the `.initial` option, so the current value is
        // read in the caller's context instead of KVO's.
        continuation.yield(object[keyPath: keyPath])

        // The value is read back off the object rather than taken from the change dictionary.
        // KVO stores it as an `NSNumber`, and for a property whose Swift type is an imported
        // `@objc` enum - `AVPlayerItem.Status`, `AVPlayer.TimeControlStatus` - that number won't
        // cast back to the enum, so `change.newValue` is nil and the change looks like it never
        // happened. Reading the property is always correctly typed.
        let observation = object.observe(keyPath) { object, _ in
            continuation.yield(object[keyPath: keyPath])
        }

        continuation.onTermination = { _ in
            observation.invalidate()
        }
    }
}
