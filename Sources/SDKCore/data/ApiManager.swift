//
//  ApiManager.swift
//
//  Created by Mitch Flindell on 18/11/2022.
//

import Alamofire
import Foundation
import UserNotifications

public protocol ApiManagerInterface {
    /**
     Register a new device with Orttos API
     */
    func sendRegisterIdentity(_ storage: UserStorage) async throws -> IdentityRegistrationResponse?
    func sendLinkTracking(_ trackingUrl: URL) async throws
    func sendScreenView(_ screenName: String) async throws -> MobileScreenViewResponse?
}

enum APIResponseError: Error {
    case noStatusCode
    case notSuccessful
}

public class ApiManager: ApiManagerInterface {

    /**
     Send an Identify request to Ortto
     */
    public func sendRegisterIdentity(_ storage: UserStorage) async throws -> IdentityRegistrationResponse? {
        var components = URLComponents(string: Ortto.shared.apiEndpoint!)!
        components.path = "/-/events/push-mobile-session"
        components.queryItems = DeviceIdentity.getTrackingQueryItems()

        guard let user = storage.user else {
            Ortto.log().info("ApiManager@registerIdentity.noUserIdentified")

            return nil
        }

        let identityRegistration = PushMobileSessionRequest(
            appKey: Ortto.shared.appKey!,
            contactID: user.contactID,
            associationEmail: user.email,
            associationPhone: user.phone,
            associationExternalID: user.externalID,
            sessionID: storage.session,
            firstName: user.firstName,
            lastName: user.lastName,
            acceptGDPR: user.acceptsGDPR,
            platform: "ios",
            shouldSkipNonExistingContacts: Ortto.shared.shouldSkipNonExistingContacts
        )

        #if DEBUG
            debugPrint(identityRegistration)
        #endif

        Ortto.log().info("ApiManager@registerIdentity sending SessionID: \(identityRegistration.sessionID ?? "nil")")

        let headers: HTTPHeaders = [
            .accept("application/json"),
            .userAgent(Alamofire.HTTPHeader.defaultUserAgent.value),
        ]

        let dataTask = AF
            .request(components.url!, method: .post, parameters: identityRegistration, encoder: JSONParameterEncoder.default, headers: headers)
            .validate()
            .serializingDecodable(IdentityRegistrationResponse.self)

        let response = await dataTask.response

        guard let statusCode = response.response?.statusCode else {
            throw APIResponseError.noStatusCode
        }

        Ortto.log().info("ApiManager@registerIdentity status=\(statusCode)")

        let value = try await dataTask.value

        return value
    }

    /**
     Send a screen view tracking request to Ortto
     */
    public func sendScreenView(_ screenName: String) async throws -> MobileScreenViewResponse? {
        return try await Ortto.shared.requestQueue.enqueue {
            guard let endpoint = Ortto.shared.apiEndpoint else {
                return nil
            }

            var components = URLComponents(string: endpoint)!
            components.path = "/-/events/mobile-screen-view"
            components.queryItems = DeviceIdentity.getTrackingQueryItems()

            // For now, send empty push token info (matches Android implementation)
            let screenViewRequest = MobileScreenViewRequest(
                appKey: Ortto.shared.appKey!,
                pushToken: "",
                pushTokenType: "",
                title: nil,
                sessionKey: Ortto.shared.userStorage.session,
                url: screenName,
                contactId: Ortto.shared.userStorage.user?.contactID,
                associationEmail: Ortto.shared.userStorage.user?.email,
                associationPhone: Ortto.shared.userStorage.user?.phone,
                associationExternalId: Ortto.shared.userStorage.user?.externalID,
                strategy: nil,
                session: Ortto.shared.userStorage.session,
                firstName: Ortto.shared.userStorage.user?.firstName,
                lastName: Ortto.shared.userStorage.user?.lastName,
                acceptGDPR: Ortto.shared.userStorage.user?.acceptsGDPR,
                skipNonExistingContacts: Ortto.shared.shouldSkipNonExistingContacts
            )

            let headers: HTTPHeaders = [
                .accept("application/json"),
                .userAgent(Alamofire.HTTPHeader.defaultUserAgent.value),
            ]

            #if DEBUG
                debugPrint(screenViewRequest)
            #endif

            Ortto.log().info("ApiManager@sendScreenView sending screen: \(screenName), sessionKey: \(screenViewRequest.sessionKey ?? "nil")")

            return try await withCheckedThrowingContinuation { continuation in
                AF.request(components.url!, method: .post, parameters: screenViewRequest, encoder: JSONParameterEncoder.default, headers: headers)
                    .validate()
                    .responseDecodable(of: MobileScreenViewResponse.self) { response in
                        guard let data = response.data, let statusCode = response.response?.statusCode else {
                            continuation.resume(returning: nil)
                            return
                        }

                        guard let json = String(data: data, encoding: .utf8) else {
                            continuation.resume(returning: nil)
                            return
                        }

                        Ortto.log().info("ApiManager@sendScreenView status=\(statusCode) body=\(json)")

                        switch response.result {
                        case .success(let screenViewResponse):
                            continuation.resume(returning: screenViewResponse)
                        case let .failure(error):
                            Ortto.log().error("ApiManager@sendScreenView.request.fail \(error.localizedDescription)")
                            continuation.resume(throwing: error)
                        }
                    }
            }
        }
    }

    public func sendLinkTracking(_ trackingUrl: URL) async throws {
        let dataTask = AF
            .request(trackingUrl, method: .get)
            .validate()
            .serializingString()

        let response = await dataTask.response

        guard let statusCode = response.response?.statusCode,
              (200 ... 299).contains(statusCode)
        else {
            throw APIResponseError.notSuccessful
        }
    }

    func debug(name: String, _ model: Codable) {
        do {
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(model)
            guard let jsonString = String(data: encoded, encoding: .utf8) else {
                return
            }

            print("ApiManager.debug \(name): \(jsonString)")
        } catch {
            debugPrint(error)
        }
    }
}
