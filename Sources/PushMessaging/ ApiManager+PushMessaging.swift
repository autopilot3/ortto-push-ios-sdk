//
//  ApiManager+PushMessaging.swift
//
//
//  Created by Mitchell Flindell on 21/5/2024.
//

import Foundation
import Alamofire
import OrttoSDKCore

extension ApiManagerInterface {
    func sendPushPermission(sessionID: String, token: PushToken, permission: Bool, completion: @escaping (PushRegistrationResponse?) -> Void) {
        guard let endpoint = Ortto.shared.apiEndpoint else {
            completion(nil)
            return
        }

        var components = URLComponents(string: endpoint)!
        components.path = "/-/events/push-permission"
        components.queryItems = DeviceIdentity.getTrackingQueryItems()

        let tokenRegistration = PushPermissionRequest(
            appKey: Ortto.shared.appKey!,
            permission: permission,
            sessionID: sessionID,
            deviceToken: token.value,
            pushTokenType: token.type
        )

        let headers: HTTPHeaders = [
            .accept("application/json"),
            .userAgent(Alamofire.HTTPHeader.defaultUserAgent.value),
        ]

        #if DEBUG
            debugPrint(tokenRegistration)
        #endif

        AF.request(components.url!, method: .post, parameters: tokenRegistration, encoder: JSONParameterEncoder.default, headers: headers)
            .validate()
            .responseDecodable(of: DecodableType.self) { response in
                guard let data = response.data, let statusCode = response.response?.statusCode else {
                    completion(nil)
                    return
                }

                guard let json = String(data: data, encoding: .utf8) else {
                    completion(nil)
                    return
                }

                Ortto.log().info("PushMessaging@registerDeviceToken status=\(statusCode) body=\(json)")

                switch response.result {
                case .success:
                    let decoder = JSONDecoder()
                    do {
                        let registration = try decoder.decode(PushRegistrationResponse.self, from: data)
                        completion(registration)
                    } catch {
                        Ortto.log().error("PushMessaging@registerDeviceToken.decode.error \(error.localizedDescription)")
                        completion(nil)
                    }
                case let .failure(error):
                    Ortto.log().error("PushMessaging@registerDeviceToken.request.fail \(error.localizedDescription)")
                    completion(nil)
                }
            }
    }
}
