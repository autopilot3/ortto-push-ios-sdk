//
//  PushProvider.swift
//  Ortto iOS SDK Push Demo
//

import Foundation

enum PushProvider: String {
    case apns = "APNS"
    case fcm = "FCM"

    var targetTitle: String {
        switch self {
        case .apns: return "APNS-only"
        case .fcm: return "FCM-only"
        }
    }

    var tokenType: String {
        switch self {
        case .apns: return "apn"
        case .fcm: return "fcm"
        }
    }
}
