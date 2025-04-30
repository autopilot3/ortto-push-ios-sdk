//
//  MessagingPush+AppDelegate.swift
//  Extension to the PushMessaging class when UIKit is available which handles deep links
//
//  Created by Mitch Flindell on 18/11/2022.
//

import Foundation
import OrttoSDKCore

#if canImport(UserNotifications) && canImport(UIKit)
    import UIKit
    import UserNotifications
#endif

#if canImport(UserNotifications) && canImport(UIKit)
    @available(iOSApplicationExtension, unavailable)
    public extension PushMessaging {
        /**
            Accept an action click on a notification
         */
        func userNotificationCenter(_: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) -> Bool {
            let userInfo: [AnyHashable: Any] = response.notification.request.content.userInfo
            let key: String = response.actionIdentifier

            guard let deepLink = userInfo[key] as? String else {
                return false
            }

            guard let url = URL(string: deepLink) else {
                return false
            }

            if !UIApplication.shared.canOpenURL(url) {
                DispatchQueue.main.async {
                    completionHandler()
                }
                return false
            }

            if #available(iOS 10.0, *) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                UIApplication.shared.openURL(url)
            }

            Ortto.shared.trackLinkClick(deepLink) {
                DispatchQueue.main.async {
                    completionHandler()
                }
            }

            return true
        }
    }
#endif
