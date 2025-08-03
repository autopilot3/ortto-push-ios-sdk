import Foundation

public class OrttoRequestQueue {
    public static let shared = OrttoRequestQueue()
    private let queue = DispatchQueue(label: "com.ortto.requestQueue")
    private var lastTask: Task<Void, Never>?

    private init() {}

    public func enqueue<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        Ortto.log().info("OrttoRequestQueue@enqueue: Request enqueued")
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                Ortto.log().info("OrttoRequestQueue@process: Processing request from queue")
                let task = Task {
                    do {
                        let result = try await operation()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
                self.lastTask = task
            }
        }
    }
}
