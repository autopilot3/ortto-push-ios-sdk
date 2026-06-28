//
//  AppLog.swift
//  Ortto iOS SDK Push Demo
//

import Foundation
@preconcurrency import OrttoSDKCore

// Thread-safe: all mutable state (`history`) is guarded by `lock`, so the shared
// `appLog` global is safe to use from any concurrency domain (incl. SDK logger
// callbacks on background threads).
final class AppLog: OrttoLogger, @unchecked Sendable {
    private let lock = NSLock()
    private var history: [LogEntry] = []

    var recentEntries: [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return history
    }

    func info(_ message: String)  { post(.info, message, source: .sdk) }
    func warn(_ message: String)  { post(.warning, message, source: .sdk) }
    func error(_ message: String) { post(.error, message, source: .sdk) }
    func debug(_ message: String) { post(.debug, message, source: .sdk) }

    func appInfo(_ message: String)  { post(.info, message, source: .demo) }
    func appWarn(_ message: String)  { post(.warning, message, source: .demo) }
    func appError(_ message: String) { post(.error, message, source: .demo) }

    private func post(_ level: LogLevel, _ message: String, source: LogSource) {
        let entry = LogEntry(source: source, level: level, message: message)
        lock.lock()
        history.append(entry)
        lock.unlock()
        print(entry.consoleLine)
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .logEntry,
                object: nil,
                userInfo: ["entry": entry]
            )
        }
    }
}

let appLog = AppLog()
