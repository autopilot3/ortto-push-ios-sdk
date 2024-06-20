//
//  Ortto.swift
//
//  Created by Mitch Flindell on 17/11/2022.
//

import Alamofire
import Foundation
#if canImport(UIKit)
    import UIKit
#endif

let version: String = "1.5.7"

public protocol OrttoInterface {
    var appKey: String? { get }
    var apiEndpoint: String? { get }
    func identify(_ user: UserIdentifier)
}

public struct SDKConfiguration {
    var appKey: String?
    var apiEndpoint: String?
}

public class Ortto: OrttoInterface {
    public var appKey: String?
    public var apiEndpoint: String?

    public private(set) static var shared = Ortto()

    public var apiManager: ApiManagerInterface
    public var preferences: PreferencesInterface = OrttoPreferencesManager()
    public var userStorage: UserStorage
    private var logger: OrttoLogger = PrintLogger()
    public private(set) var screenName: String?

    /**
     Overwrite Logging service
     */
    public func setLogger(customLogger: OrttoLogger) {
        logger = customLogger
    }

    public static func log() -> OrttoLogger {
        return shared.logger
    }

    private init() {
        userStorage = OrttoUserStorage(preferences)
        apiManager = ApiManager()
    }

    @available(iOSApplicationExtension, unavailable)
    public static func initialize(appKey: String, endpoint: String?, completionHandler: ((SDKConfiguration) -> Void)? = nil) {
        shared.apiEndpoint = {
            guard let endpoint = endpoint else {
                return nil
            }

            return endpoint.hasSuffix("/") ? String(endpoint.dropLast()) : endpoint
        }()

        shared.appKey = appKey

        let sdkConfiguration = SDKConfiguration(appKey: appKey, apiEndpoint: endpoint)
        completionHandler?(sdkConfiguration)
    }

    public func clearData() {
        preferences.clear()
    }

    public func setSessionID(_ sessionID: String) {
        userStorage.session = sessionID
    }

    /**
     Identify user to the Ortto API
     Endpoint: "/-/events/push-mobile-session"
     */
    public func identify(_ user: UserIdentifier) {
        userStorage.user = user

        Task {
            do {
                let response = try await apiManager.sendRegisterIdentity(userStorage)
                guard let sessionID = response?.sessionID else {
                    return
                }

                self.userStorage.session = sessionID
                self.logger.info("Ortto@identify.success \(sessionID)")
            } catch {
                self.logger.info("Ortto@identify.error \(error.localizedDescription)")
            }
        }
    }

    /**
     * Retrieve the utm_X parameters from the deep link
     */
    public func retrieveUtmParameters(_ encodedUrl: String) -> LinkUtm? {
        guard let url = URL(string: encodedUrl) else {
            Ortto.log().error("could not decode tracking_url: \(encodedUrl)")
            return nil
        }

        guard let components = URLComponents(string: url.absoluteString) else { return nil }
        guard let queryItems = components.queryItems else { return nil }

        let utm = LinkUtm(queryItems)

        return utm
    }

    func base64UrlDecode(_ base64Url: String) -> Data? {
        var base64 = base64Url
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let paddingLength = (4 - (base64.count % 4)) % 4
        base64.append(contentsOf: repeatElement("=", count: paddingLength))
        
        return Data(base64Encoded: base64)
    }
    
    func base64urlToBase64(base64url: String) -> String {
        var base64 = base64url
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        if base64.count % 4 != 0 {
            base64.append(String(repeating: "=", count: 4 - base64.count % 4))
        }
        return base64
    }
    
    /**
     Track the clicking of a link and return the utm values for the developer to use for marketing
     */
    public func trackLinkClick(_ encodedUrl: String, completion: @escaping () -> Void) {

        guard let url = URL(string: encodedUrl) else {
            Ortto.log().error("could not decode tracking_url: \(encodedUrl)")
            return
        }

        guard let components = URLComponents(string: url.absoluteString),
              let queryItems = components.queryItems else {
            return
        }

        let items = queryItems.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        }
    
        
        guard let trackingUrl = items["tracking_url"] else {
            return
        }
        
        let trackingUrlDecoded = base64urlToBase64(base64url: trackingUrl)

        guard let burl = URL(string: "data:application/octet-stream;base64," + trackingUrlDecoded),
              let data = try? Data(contentsOf: burl),
              let trackingUrlFinal = String(data: data, encoding: .utf8),
              var urlComponents = URLComponents(string: trackingUrlFinal)
        else {
            Ortto.log().error("could not get tracking_url: \(encodedUrl)")
            return
        }

        for item in DeviceIdentity.getTrackingQueryItems() {
            urlComponents.queryItems?.append(item)
        }

        guard let finalURL = urlComponents.url else { return }

        Task {
            do {
                try await apiManager.sendLinkTracking(finalURL)
                self.logger.debug("Ortto@trackLinkClick.success")
                completion()
            } catch {
                self.logger.info("Ortto@trackLinkClick.error \(error.localizedDescription)")
            }
        }
    }

    public func screen(_ screenName: String) {
        self.screenName = screenName
    }
}
