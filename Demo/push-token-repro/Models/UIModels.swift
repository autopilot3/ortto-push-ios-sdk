//
//  UIModels.swift
//  Ortto iOS SDK Push Demo
//

import Foundation
import SwiftUI

extension PushProvider {
    var title: String {
        switch self {
        case .apns: return "Apple Push Notification service"
        case .fcm: return "Firebase Cloud Messaging"
        }
    }

    var loginBaseColors: [Color] {
        switch self {
        case .apns:
            return [
                AppColor.blue,
                Color(red: 0.22, green: 0.93, blue: 0.90),
                AppColor.lilac
            ]
        case .fcm:
            return [
                AppColor.lilac,
                AppColor.orange,
                AppColor.yellow
            ]
        }
    }
}

enum AppTab: Hashable {
    case home
    case delivery
    case diagnostics

    var screenName: String {
        switch self {
        case .home: return "sdk-home"
        case .delivery: return "push-delivery"
        case .diagnostics: return "push-diagnostics"
        }
    }
}

enum SDKActionID: Hashable {
    case identify
    case registerPush
    case logAPNSToken
    case redispatch
    case trackLink
    case refreshPermission
}

struct SDKConfigurationIssue: Identifiable, Equatable {
    let title: String
    let detail: String
    let severity: SDKConfigurationSeverity

    var id: String { title }
}

enum SDKConfigurationSeverity: Equatable {
    case warning
    case critical

    var tint: Color {
        switch self {
        case .warning: return AppColor.orange
        case .critical: return AppColor.coral
        }
    }
}

struct SDKActionStatus: Equatable {
    let text: String
    let tone: SDKActionTone
}

struct SDKToast: Equatable {
    let id = UUID()
    let title: String
    let detail: String
    let tone: SDKActionTone
}

enum SDKActionTone: Equatable {
    case ready
    case working
    case success
    case warning
    case blocked

    var symbol: String {
        switch self {
        case .ready: return "circle"
        case .working: return "clock.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .blocked: return "slash.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .ready: return AppColor.ink.opacity(0.48)
        case .working: return AppColor.lilac
        case .success: return AppColor.green
        case .warning: return AppColor.orange
        case .blocked: return AppColor.coral
        }
    }
}
