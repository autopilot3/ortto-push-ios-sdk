import Alamofire
import Foundation
import OrttoSDKCore

extension ApiManagerInterface {

    func sendPushPermission(sessionID: String?, token: PushToken, permission: Bool) async throws -> PushRegistrationResponse? {
        return try await Ortto.shared.requestQueue.enqueue {
            guard let endpoint = Ortto.shared.apiEndpoint else {
                return nil
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

            Ortto.log().info("PushMessaging@sendPushPermission sending SessionID: \(tokenRegistration.sessionID)")

            return try await withCheckedThrowingContinuation { continuation in
                AF.request(components.url!, method: .post, parameters: tokenRegistration, encoder: JSONParameterEncoder.default, headers: headers)
                    .validate()
                    .responseDecodable(of: PushRegistrationResponse.self) { response in
                        guard let data = response.data, let statusCode = response.response?.statusCode else {
                            continuation.resume(returning: nil)
                            return
                        }

                        guard let json = String(data: data, encoding: .utf8) else {
                            continuation.resume(returning: nil)
                            return
                        }

                        Ortto.log().info("PushMessaging@registerDeviceToken status=\(statusCode) body=\(json)")

                        switch response.result {
                        case .success(let registration):
                            continuation.resume(returning: registration)
                        case let .failure(error):
                            Ortto.log().error("PushMessaging@registerDeviceToken.request.fail \(error.localizedDescription)")
                            continuation.resume(returning: nil)
                        }
                    }
            }
        }
    }

    // Backward compatible version
    func sendPushPermission(sessionID: String?, token: PushToken, permission: Bool, completion: @escaping (PushRegistrationResponse?) -> Void) {
        Task {
            let result = try? await sendPushPermission(sessionID: sessionID, token: token, permission: permission)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}
