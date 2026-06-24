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
    private let deliveriesLock = NSLock()
    private var activeDeliveries: [NotificationDelivery] = []

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
        // TEMP(testing): capture the raw incoming payload to see exactly what the backend
        // sends — especially whether each action carries an `action` identifier.
        Ortto.log().info("MessagingService@didReceive.raw actions=\(request.content.userInfo["actions"] ?? "nil") primary_action=\(request.content.userInfo["primary_action"] ?? "nil") keys=\(Array(request.content.userInfo.keys))")
        guard let pushPayload = PushNotificationPayload.parse(request.content) else {
            Ortto.log().warn("MessagingService@didReceive.content.parse-fail")
            return false
        }

        let http = httpClientFactory()
        let categoryID = Self.categoryIdentifier(for: pushPayload, requested: request.content.categoryIdentifier)
        let content = buildContent(from: pushPayload, categoryID: categoryID)
        let category = buildCategory(from: pushPayload, categoryID: categoryID)
        let delivery = NotificationDelivery(content: content, contentHandler: contentHandler)
        addDelivery(delivery)

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
            self.removeDelivery(delivery)
        }

        return true
    }

    /// Expires every notification delivery currently in flight and sends the best content assembled so far for each.
    /// `serviceExtensionTimeWillExpire()` is the system telling the whole NSE process to wrap up, so we drain the list.
    public func serviceExtensionTimeWillExpire() {
        for delivery in drainDeliveries() {
            delivery.expire()
        }
    }

    private func addDelivery(_ delivery: NotificationDelivery) {
        deliveriesLock.lock()
        defer { deliveriesLock.unlock() }
        activeDeliveries.append(delivery)
    }

    private func removeDelivery(_ delivery: NotificationDelivery) {
        deliveriesLock.lock()
        defer { deliveriesLock.unlock() }
        activeDeliveries.removeAll { $0 === delivery }
    }

    private func drainDeliveries() -> [NotificationDelivery] {
        deliveriesLock.lock()
        defer { deliveriesLock.unlock() }
        let copy = activeDeliveries
        activeDeliveries.removeAll()
        return copy
    }

    // MARK: - Private helpers

    private func buildContent(
        from payload: PushNotificationPayload,
        categoryID: String
    ) -> UNMutableNotificationContent {
        var actionLinks: [String: String] = [:]

        // Index, not action.action — the backend sends the action TYPE (e.g. "page"),
        // which repeats across buttons; using it as the id collides. Must match the
        // UNNotificationAction id built in buildCategory so a tap resolves the right link.
        for (index, action) in payload.actions.enumerated() {
            actionLinks["\(categoryID).\(index)"] = action.link
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
        let actions: [UNNotificationAction] = payload.actions.enumerated().map { index, item in
            UNNotificationAction(
                identifier: "\(categoryID).\(index)",
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

    // Each push gets its own category id to avoid otherwise new notification reusing
    // the previous push item ID's
    private static let dynamicCategoryPrefix = "ORTTO_ACTIONS."
    private static let maxDynamicCategories = 64

    /// A unique category id for this push, so its buttons always match its own actions.
    /// The send time is zero-padded so sorting the ids alphabetically is also oldest-first.
    static func categoryIdentifier(for payload: PushNotificationPayload, requested: String) -> String {
        guard !payload.actions.isEmpty else { return requested }
        let sendTime = String(format: "%015ld", Int(Date().timeIntervalSince1970 * 1000))
        return "\(dynamicCategoryPrefix)\(sendTime).\(payload.notificationID)"
    }

    /// Adds `category`, replacing any with the same id, then keeps only the newest
    /// `maxDynamicCategories` ids this SDK created (oldest dropped first).
    static func categories(
        byAdding category: UNNotificationCategory,
        to existing: Set<UNNotificationCategory>
    ) -> Set<UNNotificationCategory> {
        var kept = existing.filter { $0.identifier != category.identifier }
        kept.insert(category)

        let oursOldestFirst = kept.map(\.identifier)
            .filter { $0.hasPrefix(dynamicCategoryPrefix) }
            .sorted()
        let stale = Set(oursOldestFirst.dropLast(maxDynamicCategories))
        return kept.filter { !stale.contains($0.identifier) }
    }

    private static func registerCategoryWithNotificationCenter(
        _ category: UNNotificationCategory
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            let center = UNUserNotificationCenter.current()
            center.getNotificationCategories { existing in
                center.setNotificationCategories(categories(byAdding: category, to: existing))
                center.getNotificationCategories { _ in continuation.resume(returning: true) }
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
        private let lock = NSLock()
        private var didDeliver = false

        init(
            content: UNMutableNotificationContent,
            contentHandler: @escaping (UNNotificationContent) -> Void
        ) {
            self.content = content
            self.contentHandler = contentHandler
        }

        /// Delivers the notification content exactly once. The lock guards a TOCTOU race between
        /// the enrichment Task completing normally and `expire()` firing from the NSE callback thread.
        func deliver() {
            lock.lock()
            let shouldDeliver = !didDeliver
            didDeliver = true
            lock.unlock()
            if shouldDeliver { contentHandler(content) }
        }

        /// Cancels enrichment work and immediately delivers whatever content has been assembled.
        func expire() {
            task?.cancel()
            deliver()
        }
    }
#endif
