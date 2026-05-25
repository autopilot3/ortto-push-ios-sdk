//
//  MessagingService.swift
//  Central Push Messaging service implementation class. Handles Push notification requests
//
//  Created by Mitch Flindell on 18/11/2022.
//

import Foundation
import OrttoSDKCore

#if canImport(UserNotifications)
    @preconcurrency import UserNotifications
#endif

// Used for rich push
protocol MessagingServiceProtocol {
    #if canImport(UserNotifications)
        @discardableResult
        func didReceive(
            _ request: UNNotificationRequest,
            withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
        ) -> Bool

        func serviceExtensionTimeWillExpire()
    #endif
}

public class MessagingService: MessagingServiceProtocol {
    public private(set) static var shared = MessagingService()

    private let httpClientFactory: () -> OrttoHTTPClient
    private let categoryRegistrar: (UNNotificationCategory) async -> Bool
    private var currentDelivery: NotificationDelivery?

    /// Creates the service. The factory is called once per `didReceive` so each notification
    /// enrichment has its own URL session — cancelling one does not affect others.
    init(
        httpClientFactory: @escaping () -> OrttoHTTPClient = { OrttoURLSessionHTTPClient() },
        categoryRegistrar: @escaping (UNNotificationCategory) async -> Bool = {
            await MessagingService.registerCategoryWithNotificationCenter($0)
        }
    ) {
        self.httpClientFactory = httpClientFactory
        self.categoryRegistrar = categoryRegistrar
    }

    // MARK: - App-side push registration

    /// Stores the device token and dispatches registration when identity is available.
    public func registerDeviceToken(token: String, tokenType: String) {
        Ortto.shared.dispatchPushRequest(PushToken(value: token, type: tokenType))
    }

    /// Clears the current device's push permission on the Ortto API.
    public func clearIdentity(completion: @escaping (PushRegistrationResponse?) -> Void) {
        guard let sessionID = Ortto.shared.userStorage.session,
              let token = PushMessaging.shared.token
        else {
            completion(nil)
            return
        }

        Ortto.shared.apiManager.sendPushPermission(
            sessionID: sessionID,
            token: token,
            permission: false,
            completion: completion
        )
    }

    /// Registers the current device token and permission for an identified session.
    func registerDeviceToken(
        sessionID: String?,
        token: PushToken,
        completion: @escaping (PushRegistrationResponse?) -> Void
    ) {
        Ortto.shared.apiManager.sendPushPermission(
            sessionID: sessionID,
            token: token,
            permission: PushMessaging.shared.permission.isAllowed(),
            completion: completion
        )
    }

    // MARK: - NSE notification enrichment

    #if canImport(UserNotifications)
    /// Intercepts Ortto push notifications, adds actions/media, tracks delivery, and delivers modified content.
    @discardableResult
    public func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) -> Bool {
        guard let pushPayload = PushNotificationPayload.parse(request.content) else {
            Ortto.log().warn("MessagingService@didReceive.content.parse-fail")
            return false
        }

        let http = httpClientFactory()
        let content = buildContent(from: pushPayload, categoryID: request.content.categoryIdentifier)
        let category = buildCategory(from: pushPayload, categoryID: request.content.categoryIdentifier)
        let delivery = NotificationDelivery(content: content, contentHandler: contentHandler)
        currentDelivery = delivery

        delivery.task = Task { [weak self, weak delivery] in
            guard let self, let delivery else { return }

            async let attachment = NotificationAttachmentDownloader(httpClient: http)
                .optionalAttachment(from: pushPayload.image)
            async let tracking: Void = self.trackDelivery(pushPayload.eventTrackingUrl, using: http)

            if let imageAttachment = await attachment {
                content.attachments = [imageAttachment]
            }

            _ = await tracking

            guard !Task.isCancelled else { return }

            _ = await self.categoryRegistrar(category)
            delivery.deliver()

            if self.currentDelivery === delivery {
                self.currentDelivery = nil
            }
        }

        return true
    }

    /// Expires the current notification delivery and sends the best content assembled so far.
    public func serviceExtensionTimeWillExpire() {
        currentDelivery?.expire()
        currentDelivery = nil
    }

    // MARK: - Private helpers

    private func buildContent(
        from payload: PushNotificationPayload,
        categoryID: String
    ) -> UNMutableNotificationContent {
        var actionLinks: [String: String] = [:]

        for action in payload.actions {
            guard let identifier = action.action else { continue }
            actionLinks[identifier] = action.link
        }

        if let primaryAction = payload.primaryAction {
            actionLinks[UNNotificationDefaultActionIdentifier] = primaryAction.link
        }

        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.body
        content.sound = .default
        content.userInfo = actionLinks
        content.categoryIdentifier = categoryID
        return content
    }

    private func buildCategory(
        from payload: PushNotificationPayload,
        categoryID: String
    ) -> UNNotificationCategory {
        let actions: [UNNotificationAction] = payload.actions.compactMap { item in
            guard let identifier = item.action else { return nil }
            return UNNotificationAction(
                identifier: identifier,
                title: item.title ?? "",
                options: [.foreground]
            )
        }

        return UNNotificationCategory(
            identifier: categoryID,
            actions: actions,
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
    }

    /// Records notification delivery by sending a `TrackDeliveryRequest` through a
    /// per-notification connector. Failures are logged and swallowed — a failed tracking
    /// call must never block notification delivery.
    private func trackDelivery(_ trackingURLString: String?, using http: OrttoHTTPClient) async {
        guard let trackingURLString, let url = URL(string: trackingURLString) else { return }
        do {
            _ = try await OrttoAPIConnector(http: http).send(TrackDeliveryRequest(trackingURL: url))
        } catch {
            Ortto.log().debug("MessagingService@tracking.fail \(error.localizedDescription)")
        }
    }

    /// Registers a notification category with the system notification center.
    private static func registerCategoryWithNotificationCenter(
        _ category: UNNotificationCategory
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationCategories { existing in
                var all = existing
                all.insert(category)
                UNUserNotificationCenter.current().setNotificationCategories(all)
                UNUserNotificationCenter.current().getNotificationCategories { _ in
                    continuation.resume(returning: true)
                }
            }
        }
    }
    #endif
}

#if canImport(UserNotifications)
    /// Owns the content and lifecycle of one NSE notification delivery.
    /// `deliver()` is guarded so `contentHandler` is called at most once,
    /// whether delivery completes normally or the extension expires first.
    private final class NotificationDelivery {
        let content: UNMutableNotificationContent
        var task: Task<Void, Never>?

        private let contentHandler: (UNNotificationContent) -> Void
        private var didDeliver = false

        init(
            content: UNMutableNotificationContent,
            contentHandler: @escaping (UNNotificationContent) -> Void
        ) {
            self.content = content
            self.contentHandler = contentHandler
        }

        /// Delivers the notification content exactly once.
        func deliver() {
            guard !didDeliver else { return }
            didDeliver = true
            contentHandler(content)
        }

        /// Cancels enrichment work and immediately delivers whatever content has been assembled.
        func expire() {
            task?.cancel()
            deliver()
        }
    }
#endif
