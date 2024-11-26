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
