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
        
        if let widgetId = PushMessaging.getWidgetIdFromFragment(url) {
            Ortto.shared.capture?.queueWidget(widgetId)
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
    
    static func getWidgetIdFromFragment(_ url: URL?) -> String? {
        let regex = try? NSRegularExpression(pattern: "widget_id=(?<widgetId>[a-z0-9]+)", options: [.caseInsensitive])
        
        if let fragment = url?.fragment {
            let range = NSRange(location: 0, length: fragment.utf16.count)
            
            if let match = regex?.firstMatch(in: fragment, range: range) {
                let widgetIdRange = match.range(withName: "widgetId")
                let widgetId = fragment[Range(widgetIdRange, in: fragment)!]
                
                return String(widgetId)
            }
        }
        
        return nil
    }
}
#endif
