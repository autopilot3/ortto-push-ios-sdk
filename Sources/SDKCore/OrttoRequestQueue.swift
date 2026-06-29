//
//  OrttoRequestQueue.swift
//  FIFO serializer: each operation chains onto its predecessor, running one at a time in enqueue order regardless of caller thread.
//

import Foundation

/// Runs operations serially in enqueue order. A failure doesn't block successors; a cancelled caller still waits its turn, then throws — never jumps the queue.
public final class OrttoRequestQueue: @unchecked Sendable { // state guarded by `lock`

    private let lock = NSLock()
    private var tail: Task<Void, Never> = Task {}

    public init() {}

    public func enqueue<T>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        let task = append(operation)
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func append<T>(_ operation: @escaping @Sendable () async throws -> T) -> Task<T, Error> {
        lock.lock()
        defer { lock.unlock() }

        let predecessor = tail
        let task = Task<T, Error> {
            await predecessor.value
            try Task.checkCancellation()
            return try await operation()
        }
        tail = Task { _ = try? await task.value }
        return task
    }
}
