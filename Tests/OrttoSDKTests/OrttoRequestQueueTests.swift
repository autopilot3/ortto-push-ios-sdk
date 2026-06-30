//
//  OrttoRequestQueueTests.swift
//
//  Created on 12/6/2026.
//

import Foundation
@testable import OrttoSDKCore
import XCTest

final class OrttoRequestQueueTests: OrttoTestCase {

    private struct TestError: Error {}

    func testThrowingOperationDoesNotBlockSuccessors() async throws {
        let queue = OrttoRequestQueue()

        do {
            _ = try await queue.enqueue { () async throws -> Int in throw TestError() }
            XCTFail("Expected TestError")
        } catch is TestError {
            // expected
        }

        let value = try await queue.enqueue { 42 }
        XCTAssertEqual(value, 42)
    }

    func testCancellationReachesCallerWithoutDequeuingSuccessors() async throws {
        let queue = OrttoRequestQueue()

        // Head-of-line operation keeps the queue busy.
        let blocker = Task {
            try await queue.enqueue {
                try await Task.sleep(nanoseconds: 100_000_000)
                return "blocker"
            }
        }

        try await Task.sleep(nanoseconds: 10_000_000) // blocker enqueues first
        let cancelled = Task {
            try await queue.enqueue { "cancelled-op" }
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        cancelled.cancel()

        do {
            _ = try await cancelled.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // expected
        }

        // The queue keeps serving operations behind the cancelled one.
        let blockerValue = try await blocker.value
        XCTAssertEqual(blockerValue, "blocker")
        let after = try await queue.enqueue { "after" }
        XCTAssertEqual(after, "after")
    }

    func testOperationsRunInEnqueueOrder() async throws {
        let queue = OrttoRequestQueue()
        let order = OrderRecorder()

        var handles: [Task<Void, Error>] = []
        for index in 0 ..< 5 {
            handles.append(Task {
                try await queue.enqueue {
                    await order.record(index)
                }
            })
            // Generous spacing so enqueue order is deterministic across tasks.
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        for handle in handles {
            try await handle.value
        }

        let recorded = await order.values
        XCTAssertEqual(recorded, [0, 1, 2, 3, 4])
    }
}

private actor OrderRecorder {
    private(set) var values: [Int] = []

    func record(_ value: Int) {
        values.append(value)
    }
}
