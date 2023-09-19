//
//  File.swift
//  
//
//  Created by Mitch Flindell on 18/11/2022.
//

import Foundation
#if canImport(UserNotifications) && canImport(UIKit)
import UserNotifications
import UIKit
#endif

public protocol PushMessagingInterface {
    func registerDeviceToken(_ deviceToken: String)

    #if canImport(UserNotifications)
    @discardableResult
    func didReceive(
       _ request: UNNotificationRequest,
       withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) -> Bool

    func serviceExtensionTimeWillExpire()
    #endif

    #if canImport(UserNotifications) && canImport(UIKit)
    /*
    A push notification was interacted with.
    - returns: If the SDK called the completion handler for you indicating if the SDK took care of the request or not.
    */
    func userNotificationCenter( _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) -> Bool

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) -> PushNotificationPayload?
    #endif
}

public class PushMessaging {
    public static var shared = PushMessaging()
    
    public init() {}
}
