//
//  PushPermission.swift
//
//
//  Created by Mitch Flindell on 6/10/2023.
//

import Foundation
import OrttoSDKCore
import UserNotifications

public enum PushPermission: String {
    case Accept = "accept"
    case Deny = "deny"
    case Automatic = "automatic"

    func isAllowed() -> Bool {
        switch self {
        case .Automatic where PushMessaging.shared.token != nil:
            return determineScheduledSummaryPermission()

        case .Accept:
            return true

        case .Deny:
            return false

        default:
            return false
        }
    }

    func determineScheduledSummaryPermission() -> Bool {
        var result = false
        let semaphore = DispatchSemaphore(value: 0)

        UNUserNotificationCenter.current().getNotificationSettings { settings in

            if settings.authorizationStatus == .authorized {
                result = true
                semaphore.signal()
            }

            if #available(iOS 15.0, *) {
                if settings.scheduledDeliverySetting == .enabled {
                    result = true
                    semaphore.signal()
                }
            }

            semaphore.signal()
        }
        semaphore.wait()
        return result
    }
}
