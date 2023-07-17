//
//  MessagingPush+AppDelegate.swift
//  demo-app
//
//  Created by Mitch Flindell on 18/11/2022.
//

import Foundation
#if canImport(UserNotifications) && canImport(UIKit)
import UserNotifications
import UIKit
#endif

#if canImport(UserNotifications) && canImport(UIKit)
@available(iOSApplicationExtension, unavailable)
public extension PushMessaging {
    
    /**
        Accept an action click on a notification
     */
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) -> Bool {
        
        let userInfo: [AnyHashable : Any] = response.notification.request.content.userInfo
        let key: String = response.actionIdentifier
        
        guard let link = userInfo[key] as? String else {
            return false
        }

        guard let url = URL(string: link) else {
            return false;
        }
        
        if url.scheme == "ortto-widget" {
            guard let widgetId = url.host else {
                return false
            }
            
            guard let capture = Ortto.shared.capture else {
                return false
            }
            
            _ = capture.queueWidget(widgetId)
            completionHandler()
            return true
        }
        
        if !UIApplication.shared.canOpenURL(url) {
            completionHandler()
            return false
        }
        
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            UIApplication.shared.openURL(url)
        }

        Ortto.shared.trackLinkClick(link) {
            completionHandler()
        }
    
        return true
    }
}
#endif
