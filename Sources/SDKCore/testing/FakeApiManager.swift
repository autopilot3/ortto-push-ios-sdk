//
//  FakeApiManager.swift
//  ApiManagerInterface implementation backed by OrttoFakeRegistration entries.
//  Installed by OrttoAPI.fake([...]) during tests.
//
//  Created on 25/5/2026.
//

import Foundation

final class FakeApiManager: ApiManagerInterface {

    private let registrations: [ObjectIdentifier: OrttoFakeRegistration]

    public var appKey: String? { "fake-app-key" }

    init(_ registrations: [OrttoFakeRegistration]) {
        self.registrations = Dictionary(
            uniqueKeysWithValues: registrations.map { ($0.requestTypeID, $0) }
        )
    }

    // MARK: - ApiManagerInterface

    /// The core dispatch: look up the registration by request type and call its handler.
    /// The force-cast back to R.Response is safe — the handler was created for this exact R.self.
    public func send<R: OrttoAPIRequest>(_ request: R) async throws -> R.Response {
        guard let registration = registrations[ObjectIdentifier(R.self)] else {
            throw OrttoHTTPError.invalidRequest(
                """
                OrttoAPI.fake: no response registered for \(R.self).
                Add \(R.self).self => .make(body: ...) to OrttoAPI.fake([...]).
                """
            )
        }
        let response = try registration.handle(request) as! R.Response
        // Honour the persistence contract the real manager has.
        persistResponseState(from: response, for: request)
        return response
    }
}
