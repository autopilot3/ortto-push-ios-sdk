//
//  Ortto.swift
//
//  Created by Mitch Flindell on 17/11/2022.
//

import Foundation
#if canImport(UIKit)
    import UIKit
#endif

let version: String = "1.10.0"

public protocol OrttoInterface {
    var appKey: String? { get }
    var apiEndpoint: String? { get }
    func identify(_ user: UserIdentifier, completion: ((Result<String, Error>) -> Void)?)
    @discardableResult
    func identify(_ user: UserIdentifier) async throws -> String
}

public struct SDKConfiguration {
    var appKey: String?
    var apiEndpoint: String?
    var shouldSkipNonExistingContacts: Bool = false
}

public class Ortto: OrttoInterface {
    public var appKey: String?
    public var apiEndpoint: String?

    public private(set) static var shared = Ortto()

    public var apiManager: ApiManagerInterface
    public var httpClient: OrttoHTTPClient
    public var preferences: PreferencesInterface = OrttoPreferencesManager()
    public var userStorage: UserStorage
    /// Serial lane guarding session state: session-bound sends and the logout clear run through
    /// it (FIFO) so their reads/writes of `userStorage.session`/`.user` can't race. Settable only
    /// within the SDK (tests swap it for isolation) — external code can't reassign the live lane.
    public internal(set) var requestQueue = OrttoRequestQueue()
    public var shouldSkipNonExistingContacts: Bool = false
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
        httpClient = OrttoURLSessionHTTPClient()
        apiManager = ApiManager()
    }

    @available(iOSApplicationExtension, unavailable)
    public static func initialize(
        appKey: String,
        endpoint: String?,
        shouldSkipNonExistingContacts: Bool = false,
        completionHandler: ((SDKConfiguration) -> Void)? = nil
    ) {
        let normalizedEndpoint = endpoint.map {
            $0.hasSuffix("/") ? String($0.dropLast()) : $0
        }

        shared.apiEndpoint = normalizedEndpoint
        shared.shouldSkipNonExistingContacts = shouldSkipNonExistingContacts
        shared.appKey = appKey

        if let endpointString = normalizedEndpoint, let baseURL = URL(string: endpointString) {
            let connector = OrttoAPIConnector(
                http: shared.httpClient,
                appKey: appKey,
                baseURL: baseURL
            )
            shared.apiManager = ApiManager(connector: connector)
        }

        let sdkConfiguration = SDKConfiguration(
            appKey: appKey,
            apiEndpoint: normalizedEndpoint,
            shouldSkipNonExistingContacts: shouldSkipNonExistingContacts
        )
        completionHandler?(sdkConfiguration)
    }

    public func clearData() {
        preferences.clear()
    }

    /// Identify the user, await the session ID (POST `/-/events/push-mobile-session`). Retries transient failures; throws on permanent failure.
    @discardableResult
    public func identify(_ user: UserIdentifier) async throws -> String {
        guard let appKey = apiManager.appKey else {
            logger.info("Ortto@identify.error SDK not initialized")
            throw NSError(domain: "com.ortto", code: 1, userInfo: [NSLocalizedDescriptionKey: "SDK not initialized"])
        }

        // Captures `user` by value; `send` persists user + session together in the lane, so concurrent identifies can't cross them.
        let request = RegisterIdentityRequest(
            user: user,
            appKey: appKey,
            shouldSkipNonExistingContacts: shouldSkipNonExistingContacts
        )
        let response = try await apiManager.send(request)
        logger.info("Ortto@identify.success \(response.sessionID)")
        return response.sessionID
    }

    /// Callback variant of `identify`. Fires `completion` on the main thread.
    public func identify(_ user: UserIdentifier, completion: ((Result<String, Error>) -> Void)? = nil) {
        Task {
            do {
                let sessionID = try await identify(user)
                DispatchQueue.main.async { completion?(.success(sessionID)) }
            } catch {
                self.logger.info("Ortto@identify.error \(error.localizedDescription)")
                DispatchQueue.main.async { completion?(.failure(error)) }
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

    func base64urlToBase64(base64url: String) -> String {
        var base64 = base64url
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        if base64.count % 4 != 0 {
            base64.append(String(repeating: "=", count: 4 - base64.count % 4))
        }
        return base64
    }

    /// Decodes the embedded `tracking_url` and appends device params; `nil` if the input can't be decoded.
    private func buildTrackingURL(from encodedUrl: String) -> URL? {
        guard let url = URL(string: encodedUrl) else {
            Ortto.log().error("could not decode tracking_url: \(encodedUrl)")
            return nil
        }

        guard let components = URLComponents(string: url.absoluteString),
              let queryItems = components.queryItems else {
            return nil
        }

        let items = queryItems.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        }

        guard let trackingUrl = items["tracking_url"] else {
            return nil
        }

        let trackingUrlDecoded = base64urlToBase64(base64url: trackingUrl)

        guard let burl = URL(string: "data:application/octet-stream;base64," + trackingUrlDecoded),
              let data = try? Data(contentsOf: burl),
              let trackingUrlFinal = String(data: data, encoding: .utf8),
              var urlComponents = URLComponents(string: trackingUrlFinal)
        else {
            Ortto.log().error("could not get tracking_url: \(encodedUrl)")
            return nil
        }

        for item in DeviceIdentity.getTrackingQueryItems() {
            urlComponents.queryItems?.append(item)
        }

        return urlComponents.url
    }

    /// Track a link click; throws on network failure (the callback variant swallows it).
    public func trackLinkClick(_ encodedUrl: String) async throws {
        guard let finalURL = buildTrackingURL(from: encodedUrl) else { return }
        _ = try await apiManager.send(LinkTrackingRequest(trackingURL: finalURL))
        logger.debug("Ortto@trackLinkClick.success")
    }

    /**
     Track the clicking of a link and return the utm values for the developer to use for marketing
     */
    public func trackLinkClick(_ encodedUrl: String, completion: @escaping () -> Void) {
        Task {
            do {
                try await trackLinkClick(encodedUrl)
                completion()
            } catch {
                self.logger.info("Ortto@trackLinkClick.error \(error.localizedDescription)")
            }
        }
    }

    public func screen(_ screenName: String) {
        self.screenName = screenName
    }

    @available(iOSApplicationExtension, unavailable)
    public func openURL(_ url: URL, completionHandler: @escaping (Bool) -> Void) {
        #if os(iOS)
        DispatchQueue.main.async {
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(url, options: [:], completionHandler: completionHandler)
            } else {
                let success = UIApplication.shared.openURL(url)
                completionHandler(success)
            }
        }
        #endif
    }
}
