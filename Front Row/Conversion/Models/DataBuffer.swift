//
//  DataBuffer.swift
//  Front Row
//
//  Created by Joshua Park on 8/15/26.
//

import Foundation

/// Collects pipe output arriving on Foundation's reader queue.
final class DataBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        lock.withLock { data.append(newData) }
    }

    var value: Data {
        lock.withLock { data }
    }
}
