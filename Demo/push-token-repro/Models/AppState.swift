//
//  AppState.swift
//  Ortto iOS SDK Push Demo
//

import Foundation

enum DefaultsKey {
    static let signedInEmail = "OrttoPushDemo.signedInEmail"
    static let hasAskedFirstOpenPush = "OrttoPushDemo.hasAskedFirstOpenPush"
    static let lastIdentifiedEmail = "OrttoPushDemo.lastIdentifiedEmail"
}

enum DiagnosticsState {
    static let apnsTokenKey = "OrttoPushDemo.lastAPNSDeviceTokenHex"
    private static let legacyAPNSTokenKey = "lastDeviceTokenHex"

    // This is demo UI state, not SDK state. iOS only gives the APNS token
    // through an AppDelegate callback, so we remember the latest value to show
    // it after the Home/Delivery views refresh.
    static var apnsDeviceTokenHex: String {
        UserDefaults.standard.string(forKey: apnsTokenKey)
            ?? UserDefaults.standard.string(forKey: legacyAPNSTokenKey)
            ?? ""
    }

    @discardableResult
    static func recordAPNSDeviceToken(_ deviceToken: Data) -> String {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(hex, forKey: apnsTokenKey)
        return hex
    }
}

// Source is assigned at ingestion time. Ortto entries come from SDK logger
// callbacks or SDK lifecycle callbacks; demo entries come from this app.
enum LogSource: String {
    case sdk = "ortto"
    case demo = "demo"

    var promptHost: String {
        switch self {
        case .sdk:
            return "ios-sdk"
        case .demo:
            return "push-demo"
        }
    }
}

enum LogLevel: String {
    case info = "info"
    case warning = "warn"
    case error = "err"
    case debug = "debug"
}

struct LogEntry: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let source: LogSource
    let level: LogLevel
    let message: String

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        source: LogSource,
        level: LogLevel,
        message: String
    ) {
        self.id = id
        self.date = date
        self.source = source
        self.level = level
        self.message = message
    }

    var consoleLine: String {
        "\(source.rawValue)@\(source.promptHost) [\(level.rawValue)] % \(message)"
    }
}

extension Notification.Name {
    static let logEntry = Notification.Name("LogEntry")
}
