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
    func registerDeviceToken(sessionID: String?, deviceToken: String, tokenType: String, completion: @escaping (RegistrationResponse?) -> Void)
}

internal class ApiManager: ApiManagerInterface {
    
    internal func debug(name: String, _ model: Codable) {
        do {
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(model)
            let jsonString = String(data: encoded, encoding: .utf8)!

            Ortto.log().debug("ApiManager.debug \(name): \(jsonString)")
        } catch let error {
            debugPrint(error)
        }
    }

    private func getOs() -> String {
        return {
            let osName: String = {
                #if os(iOS)
                    #if targetEnvironment(macCatalyst)
                        return "macOS(Catalyst)"
                    #else
                        return "iOS"
                    #endif
                #elseif os(watchOS)
                    return "watchOS"
                #elseif os(tvOS)
                    return "tvOS"
                #elseif os(macOS)
                    return "macOS"
                #elseif os(Linux)
                    return "Linux"
                #elseif os(Windows)
                    return "Windows"
                #else
                    return "Unknown"
                #endif
            }()

            return osName
        }()
    }

    private func getVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion

        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    func getTrackingQueryItems() -> [URLQueryItem] {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { ptr in
                String(validatingUTF8: ptr)
            }
        }

        let info = Bundle.main.infoDictionary

        return [
            // App Name
            URLQueryItem(name: "an", value: info?["CFBundleIdentifier"] as? String ?? "Unknown"),
            // App Version
            URLQueryItem(name: "av", value: info?["CFBundleShortVersionString"] as? String ?? "Unknown"),
            // Sdk Version
            URLQueryItem(name: "sv", value: version),
            // OS Name
            URLQueryItem(name: "os", value: getOs()),
            // OS Version
            URLQueryItem(name: "ov", value: getVersion()),
            // Device
            URLQueryItem(name: "dc", value: modelCode),
        ]
    }

    /**
     Send an Identify request to Ortto
     */
    func registerIdentity(user: UserIdentifier, sessionID: String?, completion: @escaping (RegistrationResponse?) -> Void) {
        var components = URLComponents(string: Ortto.shared.apiEndpoint!)!
        components.path = "/-/events/push-mobile-session"
        components.queryItems = getTrackingQueryItems()

        guard let sessionID = sessionID else {
            Ortto.log().info("ApiManager@registerIdentity.noSessionID")

            return
        }

        let identityRegistration = PushMobileSessionRequest(
            appKey: Ortto.shared.appKey!,
            contactID: user.contactID,
            associationEmail: user.email,
            associationPhone: user.phone,
            associationExternalID: user.externalID,
            sessionID: sessionID,
            firstName: user.firstName,
            lastName: user.lastName,
            acceptGDPR: user.acceptsGDPR
        )

        let headers: HTTPHeaders = [
            .accept("application/json"),
            .userAgent(Alamofire.HTTPHeader.defaultUserAgent.value),
        ]

        AF.request(components.url!, method: .post, parameters: identityRegistration, encoder: JSONParameterEncoder.default, headers: headers)
            .validate()
            .responseDecodable(of: RegistrationResponse.self) { response in
                debugPrint(response)
                
                guard let statusCode = response.response?.statusCode else { return }

                Ortto.log().info("ApiManager@registerIdentity status=\(statusCode)")
                
                switch (response.result) {
                    case .success(let value):
                       completion(value)
                    case .failure(let error):
                        Ortto.log().error("ApiManager@registerIdentity.request.fail \(error.localizedDescription)")
                }
            }
    }

    // device token
    public func registerDeviceToken(sessionID: String?, deviceToken: String, tokenType: String = "apn", completion: @escaping (RegistrationResponse?) -> Void) {
        guard let endpoint = Ortto.shared.apiEndpoint else {
            return
        }

        var components = URLComponents(string: endpoint)!
        components.path = "/-/events/push-permission"
        components.queryItems = getTrackingQueryItems()

        let tokenRegistration = PushPermissionRequest(
            appKey: Ortto.shared.appKey!,
            permission: getPermission(),
            sessionID: sessionID,
            deviceToken: deviceToken,
            pushTokenType: tokenType
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
            .responseJSON { response in
                guard let data = response.data else { return }
                guard let statusCode = response.response?.statusCode else { return }

                let json = String(data: data, encoding: String.Encoding.utf8) ?? "none"
                Ortto.log().info("ApiManager@registerDeviceToken status=\(statusCode) body=\(json)")

                switch response.result {
                case .success:
                    let decoder = JSONDecoder()
                    do {
                        let registration = try decoder.decode(RegistrationResponse.self, from: data)
                        completion(registration)
                    } catch {
                        Ortto.log().error("ApiManager@registerDeviceToken.decode.error \(error.localizedDescription)")
                    }
                case let .failure(error):
                    Ortto.log().error("ApiManager@registerDeviceToken.request.fail \(error.localizedDescription)")
                }
            }
    }

    private func getPermission() -> Bool {
        switch Ortto.shared.permission {
        case .Automatic:
            return determineScheduledSummaryPermission() && Ortto.shared.prefsManager.hasToken()
        case .Accept:
            return true
        case .Deny:
            return false
        }
    }

    func determineScheduledSummaryPermission() -> Bool {
        var result = false
        let semaphore = DispatchSemaphore(value: 0)

        UNUserNotificationCenter.current().getNotificationSettings { settings in

            if settings.authorizationStatus == .authorized {
                result = true
                semaphore.signal()
            }

            if #available(iOS 15.0, *) {
                if settings.scheduledDeliverySetting == .enabled {
                    result = true
                    semaphore.signal()
                }
            }

            semaphore.signal()
        }
        semaphore.wait()
        return result
    }
}
