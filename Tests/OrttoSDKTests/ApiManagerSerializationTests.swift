//
//  ApiManagerSerializationTests.swift
//

import Foundation
@testable import OrttoSDKCore
import XCTest

final class ApiManagerSerializationTests: OrttoIsolatedTestCase {

    private let baseURL = URL(string: "https://api.example.test")!

    private func makeApiManager(http: MockOrttoHTTPClient) -> ApiManager {
        ApiManager(connector: OrttoAPIConnector(
            http: http,
            appKey: "app-key",
            baseURL: baseURL
        ))
    }

    /// Echoes a session keyed to each request's contactID, recording concurrency.
    private func makeResponder(_ probe: SerializationProbe) -> MockOrttoHTTPClient.SendResponder {
        { request in
            let body = try XCTUnwrap(request.httpBody)
            let payload = try JSONDecoder().decode(PushMobileSessionRequest.self, from: body)
            let index = Int((payload.contactID ?? "").dropFirst(2)) ?? -1
            probe.begin(index)
            // Random delay so completions would interleave if the queue weren't serializing.
            try await Task.sleep(nanoseconds: UInt64.random(in: 100_000 ... 3_000_000))
            probe.end()
            return .json(#"{"session_id":"session-\#(index)"}"#)
        }
    }

    func testConcurrentRequestsAreSerializedAndKeepPerCallerSession() async throws {
        let http = MockOrttoHTTPClient()
        let api = makeApiManager(http: http)
        let probe = SerializationProbe()
        http.sendResponder = makeResponder(probe)

        let count = 50
        await withTaskGroup(of: Void.self) { group in
            for index in (0 ..< count).shuffled() {
                group.addTask {
                    if let response = try? await api.send(makeIdentityRequest(index: index)) {
                        probe.receive(session: response.sessionID, for: index)
                    }
                }
            }
        }

        XCTAssertEqual(probe.maxConcurrent, 1, "requests overlapped — the queue did not serialize them")
        XCTAssertEqual(probe.received.count, count, "every caller should get a response")
        for index in 0 ..< count {
            XCTAssertEqual(probe.received[index], "session-\(index)",
                           "caller \(index) received another request's session")
        }
        XCTAssertEqual(http.sentRequests.count, count)
    }

    /// Link tracking touches no session state, so it must NOT be serialized — it
    /// should overlap freely rather than queue behind other requests.
    func testLinkTrackingIsNotSerialized() async throws {
        let http = MockOrttoHTTPClient()
        let api = makeApiManager(http: http)
        let probe = SerializationProbe()
        http.sendResponder = { _ in
            probe.begin(0)
            try await Task.sleep(nanoseconds: UInt64.random(in: 500_000 ... 3_000_000))
            probe.end()
            return .json("{}")
        }

        let count = 20
        await withTaskGroup(of: Void.self) { group in
            for index in 0 ..< count {
                group.addTask {
                    let url = URL(string: "https://api.example.test/track?x=\(index)")!
                    _ = try? await api.send(LinkTrackingRequest(trackingURL: url))
                }
            }
        }

        XCTAssertGreaterThan(probe.maxConcurrent, 1, "link tracking should not be serialized")
        XCTAssertEqual(http.sentRequests.count, count)
    }

    /// Control: bypassing the queue (straight to the connector) must overlap —
    /// proves the probe detects concurrency, so the test above can't pass by accident.
    func testRequestsBypassingTheQueueOverlap() async throws {
        let http = MockOrttoHTTPClient()
        let connector = OrttoAPIConnector(http: http, appKey: "app-key", baseURL: baseURL)
        let probe = SerializationProbe()
        http.sendResponder = makeResponder(probe)

        let count = 50
        await withTaskGroup(of: Void.self) { group in
            for index in (0 ..< count).shuffled() {
                group.addTask { _ = try? await connector.send(makeIdentityRequest(index: index)) }
            }
        }

        XCTAssertGreaterThan(probe.maxConcurrent, 1, "without the queue, concurrent requests should overlap")
        XCTAssertEqual(probe.order.count, count)
    }
}

private func makeIdentityRequest(index: Int) -> RegisterIdentityRequest {
    RegisterIdentityRequest(
        user: UserIdentifier(
            contactID: "c-\(index)",
            email: nil,
            phone: nil,
            externalID: nil,
            firstName: nil,
            lastName: nil,
            acceptsGDPR: false
        ),
        appKey: "app-key",
        shouldSkipNonExistingContacts: false
    )
}

private final class SerializationProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var inFlight = 0
    private(set) var maxConcurrent = 0
    private(set) var order: [Int] = []
    private(set) var received: [Int: String] = [:]

    func begin(_ index: Int) {
        lock.lock()
        inFlight += 1
        maxConcurrent = max(maxConcurrent, inFlight)
        order.append(index)
        lock.unlock()
    }

    func end() {
        lock.lock()
        inFlight -= 1
        lock.unlock()
    }

    func receive(session: String, for index: Int) {
        lock.lock()
        received[index] = session
        lock.unlock()
    }
}
