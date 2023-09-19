//
//  PushNotificationPayload.swift
//
//
//  Created by Mitch Flindell on 25/11/2022.
//

import Foundation
#if canImport(UserNotifications) && canImport(UIKit)
    import UserNotifications
#endif

public struct ActionItem: Codable {
    public let action: String?
    public let title: String?
    public let link: String
}

public class PushNotificationPayload: Codable {
    var actions: [ActionItem] = []
    var primaryAction: ActionItem?
    let title: String
    let body: String
    let image: String?
    let eventTrackingUrl: String?
    let link: String?
    let notificationID: String

    public init(
        title: String,
        body: String,
        image: String,
        link: String,
        actions: [ActionItem],
        primaryAction: ActionItem?,
        eventTrackingUrl: String?,
        notificationID: String
    ) {
        self.title = title
        self.body = body
        self.image = image
        self.link = link
        self.actions = actions
        self.primaryAction = primaryAction
        self.eventTrackingUrl = eventTrackingUrl
        self.notificationID = notificationID
    }

    enum CodingKeys: String, CodingKey {
        case actions
        case title
        case body
        case image
        case link
        case primaryAction = "primary_action"
        case eventTrackingUrl = "event_tracking_url"
        case notificationID = "ortto_notification_id"
    }

    #if canImport(UserNotifications)
        public static func parse(_ content: UNNotificationContent) -> PushNotificationPayload? {
            let actionsJson = content.userInfo["actions"] as? String ?? "[]"
            var actions = [ActionItem]()

            if let jsonData = actionsJson.data(using: .utf8) {
                do {
                    actions = try JSONDecoder().decode([ActionItem].self, from: jsonData)
                } catch {
                    // Handle or ignore error
                }
            }

            let link = content.userInfo["link"] as? String ?? ""
            let image = content.userInfo["image"] as? String ?? ""
            let eventTrackingUrl = content.userInfo["event_tracking_url"] as? String ?? nil
            var primaryAction: ActionItem?

            if let primaryActionJson = content.userInfo["primary_action"] as? String,
               let primaryActionJsonData = primaryActionJson.data(using: .utf8) {
                do {
                    primaryAction = try JSONDecoder().decode(ActionItem.self, from: primaryActionJsonData)
                } catch {
                    // Handle or ignore error
                }
            }

            guard let notificationID = content.userInfo["ortto_notification_id"] as? String else {
                return nil
            }

            let payload = PushNotificationPayload(
                title: content.userInfo["title"] as? String ?? content.title,
                body: content.userInfo["body"] as? String ?? content.body,
                image: image,
                link: link,
                actions: actions,
                primaryAction: primaryAction,
                eventTrackingUrl: eventTrackingUrl,
                notificationID: notificationID
            )

            return payload
        }
    #endif
}
