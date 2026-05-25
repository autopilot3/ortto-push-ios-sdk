//
//  ApiManager.swift
//  Thin wrapper around OrttoAPIConnector. Each public method guards preconditions
//  (SDK initialized, user identified) then delegates to the connector for
//  URL-building, encoding, sending, and error-wrapping.
//
//  Created by Mitch Flindell on 18/11/2022.
//

import Foundation

public protocol ApiManagerInterface {
    /// Registers the current user identity and returns the Ortto session ID.
    func sendRegisterIdentity(_ storage: UserStorage) async throws -> IdentityRegistrationResponse?

    /// Fires a GET tracking request to a pre-built URL (e.g. link-click tracking).
    func sendLinkTracking(_ trackingUrl: URL) async throws

    /// The app key this manager was configured with, or `nil` if not yet initialized.
    var appKey: String? { get }

    /// Sends any typed API request through the connector.
    /// Extensions in other modules (e.g. `OrttoPushMessaging`) use this to add
    /// endpoint methods without accessing the connector directly.
    func send<R: OrttoAPIRequest>(_ request: R) async throws -> R.Response
}

public class ApiManager: ApiManagerInterface {

    private let connector: OrttoAPIConnector?

    // MARK: - Init

    /// Creates an unconfigured manager. `send` calls fail gracefully until
    /// `Ortto.initialize()` replaces this with a connector-backed instance.
    public init() {
        connector = nil
    }

    /// Creates a fully configured manager backed by the given connector.
    /// Inject this in tests: `ApiManager(connector: OrttoAPIConnector(http: mock, ...))`
    public init(connector: OrttoAPIConnector) {
        self.connector = connector
    }

    // MARK: - ApiManagerInterface

    public var appKey: String? { connector?.appKey }

    public func send<R: OrttoAPIRequest>(_ request: R) async throws -> R.Response {
        guard let connector else {
            throw OrttoHTTPError.invalidRequest(
                "ApiManager: SDK not initialized. Call Ortto.initialize() before making API calls."
            )
        }
        return try await connector.send(request)
    }

    public func sendRegisterIdentity(_ storage: UserStorage) async throws -> IdentityRegistrationResponse? {
        guard let connector else {
            Ortto.log().error("ApiManager@registerIdentity: SDK not initialized")
            return nil
        }
        guard let user = storage.user else {
            Ortto.log().info("ApiManager@registerIdentity.noUserIdentified")
            return nil
        }

        let request = RegisterIdentityRequest(
            user: user,
            appKey: connector.appKey,
            sessionID: storage.session,
            shouldSkipNonExistingContacts: Ortto.shared.shouldSkipNonExistingContacts
        )

        let response = try await connector.send(request)
        Ortto.log().info("ApiManager@registerIdentity.success session=\(response.sessionID)")
        return response
    }

    public func sendLinkTracking(_ trackingUrl: URL) async throws {
        guard let connector else {
            Ortto.log().error("ApiManager@sendLinkTracking: SDK not initialized")
            return
        }
        try await connector.sendGet(trackingUrl)
    }
}
