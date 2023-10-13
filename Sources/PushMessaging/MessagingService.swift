//
//  MessagingService.swift
//  Central Push Messaging service implementation class. Handles Push notification requests
//
//  Created by Mitch Flindell on 18/11/2022.
//

import Alamofire
import Foundation
import OrttoSDKCore

#if canImport(UserNotifications) && canImport(UIKit)
    import UIKit
    import UserNotifications
#endif

struct RegistrationRequestBody: Codable {
    let token: String
    let profile_id: String
}

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

    var imageDownloadRequest: DataRequest?

    init() {}

    public func registerDeviceToken(token: String, tokenType: String) {
        Ortto.shared.dispatchPushRequest(PushToken(value: token, type: tokenType))
    }

    #if canImport(UserNotifications)

        public func didReceive(
            _ request: UNNotificationRequest,
            withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
        ) -> Bool {
            guard let pushPayload = PushNotificationPayload.parse(request.content) else {
                Ortto.log().warn("MessagingService@didReceive.content.parse-fail")
                return false
            }

            var userInfo: [String: String] = [:]
            var myActionList: [UNNotificationAction] = []
            for action: ActionItem in pushPayload.actions {
                myActionList.append(UNNotificationAction(
                    identifier: action.action!,
                    title: action.title ?? "",
                    options: [.foreground]
                ))
                userInfo[action.action!] = action.link
            }

            // Define the notification type
            let category = UNNotificationCategory(
                identifier: request.content.categoryIdentifier,
                actions: myActionList,
                intentIdentifiers: [],
                options: [.customDismissAction]
            )

            if let primaryAction = pushPayload.primaryAction {
                userInfo[UNNotificationDefaultActionIdentifier] = primaryAction.link
            }

            let content = UNMutableNotificationContent()
            content.title = pushPayload.title
            content.body = pushPayload.body
            content.sound = .default
            content.userInfo = userInfo
            content.categoryIdentifier = request.content.categoryIdentifier

            sendTrackingEventRequest(pushPayload.eventTrackingUrl)

            Task {
                let _ = await setCategories(newCategory: category)

                contentHandler(content)
            }

            return true
        }

        private func getMediaAttachment(for urlString: String, completion: @escaping (UIImage?) -> Void) {
            guard let url = URL(string: urlString) else {
                completion(nil)
                return
            }

            imageDownloadRequest = AF.request(url, method: .get)
            imageDownloadRequest?.responseData { response in
                guard let imageData = response.data else {
                    completion(nil)
                    return
                }
                let img = UIImage(data: imageData)!
                completion(img)
            }
        }

        private func saveImageAttachment(
            image: UIImage,
            forIdentifier identifier: String
        ) -> URL? {
            let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            let directoryPath = tempDirectory.appendingPathComponent(
                ProcessInfo.processInfo.globallyUniqueString,
                isDirectory: true
            )

            do {
                try FileManager.default.createDirectory(
                    at: directoryPath,
                    withIntermediateDirectories: true,
                    attributes: nil
                )

                let fileURL = directoryPath.appendingPathComponent(identifier)

                guard let imageData = image.pngData() else {
                    return nil
                }

                try imageData.write(to: fileURL)
                return fileURL
            } catch {
                return nil
            }
        }

        private func sendTrackingEventRequest(_ trackingUrl: String?) {
            guard let trackingUrl = trackingUrl else {
                return
            }

            var urlComponents = URLComponents(string: trackingUrl)!
            for item in DeviceIdentity.getTrackingQueryItems() {
                urlComponents.queryItems?.append(item)
            }

            AF.request(urlComponents.url!, method: .get)
                .validate()
                .response { response in
                }
        }

        func setCategories(newCategory: UNNotificationCategory) async -> Bool {
            return await withCheckedContinuation { continuation in
                UNUserNotificationCenter.current().getNotificationCategories { categories in
                    var allCategories: Set<UNNotificationCategory> = categories
                    allCategories.insert(newCategory)

                    UNUserNotificationCenter.current().setNotificationCategories(allCategories)

                    UNUserNotificationCenter.current().getNotificationCategories { _ in
                        continuation.resume(returning: true)
                    }
                }
            }
        }

        public func serviceExtensionTimeWillExpire() {
            imageDownloadRequest?.cancel()
        }

    #endif
}
