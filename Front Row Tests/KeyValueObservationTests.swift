//
//  KeyValueObservationTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

/// Stands in for the AVFoundation objects the player observes, which can't be driven to order.
private final class Probe: NSObject, @unchecked Sendable {
    @objc dynamic var value: Int = 0
}

@Suite(.timeLimit(.minutes(1)))
struct KeyValueObservationTests {

    @Test
    func theCurrentValueArrivesWithoutWaitingForAChange() async {
        let probe = Probe()
        probe.value = 7

        var values = observedValues(of: probe, at: \Probe.value).makeAsyncIterator()

        let first = await values.next()
        #expect(first == 7)
    }

    /// The defect this bridge exists for.
    ///
    /// Changes land whenever the observed object feels like it, not when the consumer happens to
    /// be waiting. `publisher(for:).values` discarded the ones that arrived in between, which
    /// left the player watching a status it had already moved past - so it never learned the item
    /// was ready, and never enabled its controls.
    @Test
    func changesThatLandWhileNobodyIsWaitingAreStillDelivered() async {
        let probe = Probe()
        var values = observedValues(of: probe, at: \Probe.value).makeAsyncIterator()

        let seed = await values.next()
        #expect(seed == 0)

        // Nothing is awaiting the stream at this point - exactly the gap values used to vanish in.
        probe.value = 1
        probe.value = 2
        probe.value = 3

        let received = [await values.next(), await values.next(), await values.next()]
        #expect(received == [1, 2, 3])
    }

    @Test
    func everyChangeIsDeliveredInOrder() async {
        let probe = Probe()
        var values = observedValues(of: probe, at: \Probe.value).makeAsyncIterator()
        _ = await values.next()

        for value in 1...50 {
            probe.value = value
        }

        var received: [Int] = []
        for _ in 1...50 {
            guard let value = await values.next() else { break }
            received.append(value)
        }

        #expect(received == Array(1...50))
    }
}
