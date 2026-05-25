//
//  OrttoCaptureFetchWidgetsTests.swift
//
//  Tests for OrttoCapture.fetchWidgets using OrttoAPI.fake to intercept
//  FetchWidgetsRequest without hitting the network.
//
//  Created on 25/5/2026.
//

import Foundation
@testable import OrttoInAppNotifications
@testable import OrttoSDKCore
import XCTest

final class OrttoCaptureFetchWidgetsTests: OrttoTestCase {

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        // Initialize a shared OrttoCapture so fetchWidgets can reference OrttoCapture.shared.
        try! OrttoCapture.initialize(
            dataSourceKey: "test-datasource-key",
            captureJsURL: "https://capture.test/js",
            apiHost: "https://api.test"
        )
        // Reset stored preferences (including session) so tests don't bleed into each other.
        // Note: the session setter force-unwraps, so we clear via preferences instead of nil-assign.
        Ortto.shared.clearData()
    }

    override func tearDown() {
        OrttoAPI.clearFakes()
        super.tearDown()
    }

    // MARK: - Helpers

    /// Wraps the callback-based `fetchWidgets` in async/await for cleaner tests.
    private func fetchWidgets(widgetId: String? = nil) async -> WidgetsResponse {
        await withCheckedContinuation { continuation in
            OrttoCapture.shared.fetchWidgets(widgetId) { response in
                continuation.resume(returning: response)
            }
        }
    }

    // MARK: - Error handling

    func testFetchWidgetsReturnsDefaultWhenRequestFails() async {
        OrttoAPI.fake([
            FetchWidgetsRequest.self => .error(status: 500, message: "internal server error"),
        ])

        let response = await fetchWidgets()

        XCTAssertTrue(response.widgets.isEmpty, "A server error should fall back to the empty default response")
    }

    func testFetchWidgetsDoesNotOverwriteExistingSessionOnError() async {
        Ortto.shared.userStorage.session = "pre-existing-session"

        OrttoAPI.fake([
            FetchWidgetsRequest.self => .error(status: 503, message: "unavailable"),
        ])

        _ = await fetchWidgets()

        // .default has sessionId == nil, so the if-let in fetchWidgets is skipped.
        XCTAssertEqual(
            Ortto.shared.userStorage.session,
            "pre-existing-session",
            "An error response must not clobber an existing session"
        )
    }

    // MARK: - Session persistence

    func testFetchWidgetsSavesSessionIdFromResponse() async {
        OrttoAPI.fake([
            FetchWidgetsRequest.self => .make(body: widgetsJSON(sessionId: "session-xyz-789")),
        ])

        _ = await fetchWidgets()

        XCTAssertEqual(Ortto.shared.userStorage.session, "session-xyz-789")
    }

    func testFetchWidgetsDoesNotUpdateSessionWhenResponseOmitsIt() async {
        Ortto.shared.userStorage.session = "original-session"

        OrttoAPI.fake([
            FetchWidgetsRequest.self => .make(body: widgetsJSON(sessionId: nil)),
        ])

        _ = await fetchWidgets()

        // session_id absent from JSON → sessionId == nil → not written
        XCTAssertEqual(Ortto.shared.userStorage.session, "original-session")
    }

    // MARK: - Widget filtering

    func testFetchWidgetsNilWidgetIdReturnsAllWidgets() async {
        let json = widgetsJSON(widgets: [
            widgetJSON(id: "w-1", type: "popup"),
            widgetJSON(id: "w-2", type: "form"),
        ])
        OrttoAPI.fake([
            FetchWidgetsRequest.self => .make(body: json),
        ])

        let response = await fetchWidgets(widgetId: nil)

        XCTAssertEqual(response.widgets.count, 2, "nil widgetId should return all widgets unfiltered")
    }

    func testFetchWidgetsFiltersToMatchingPopupWidget() async {
        let json = widgetsJSON(widgets: [
            widgetJSON(id: "widget-abc", type: "popup"),
            widgetJSON(id: "widget-def", type: "popup"),
        ])
        OrttoAPI.fake([
            FetchWidgetsRequest.self => .make(body: json),
        ])

        let response = await fetchWidgets(widgetId: "widget-abc")

        XCTAssertEqual(response.widgets.count, 1)
        XCTAssertEqual(response.widgets.first?.id, "widget-abc")
    }

    func testFetchWidgetsFiltersOutNonPopupWidgetWhenWidgetIdGiven() async {
        // "form" type is not ".popup", so filtering(for:) should exclude it.
        let json = widgetsJSON(widgets: [
            widgetJSON(id: "widget-abc", type: "form"),
        ])
        OrttoAPI.fake([
            FetchWidgetsRequest.self => .make(body: json),
        ])

        let response = await fetchWidgets(widgetId: "widget-abc")

        XCTAssertTrue(
            response.widgets.isEmpty,
            "Non-popup widgets must be excluded even when the id matches"
        )
    }

    func testFetchWidgetsFiltersOutExpiredPopupWidget() async {
        // Expiry in the past → filtering(for:) excludes the widget.
        let json = widgetsJSON(widgets: [
            widgetJSON(id: "widget-abc", type: "popup", expiry: "2000-01-01T00:00:00.000Z"),
        ])
        OrttoAPI.fake([
            FetchWidgetsRequest.self => .make(body: json),
        ])

        let response = await fetchWidgets(widgetId: "widget-abc")

        XCTAssertTrue(
            response.widgets.isEmpty,
            "A widget whose expiry is in the past must be filtered out"
        )
    }

    func testFetchWidgetsIncludesNonExpiredPopupWidget() async {
        // Expiry far in the future → widget should pass filtering(for:).
        let json = widgetsJSON(widgets: [
            widgetJSON(id: "widget-abc", type: "popup", expiry: "2099-12-31T23:59:59.000Z"),
        ])
        OrttoAPI.fake([
            FetchWidgetsRequest.self => .make(body: json),
        ])

        let response = await fetchWidgets(widgetId: "widget-abc")

        XCTAssertEqual(response.widgets.count, 1)
        XCTAssertEqual(response.widgets.first?.id, "widget-abc")
    }

    func testFetchWidgetsReturnsEmptyWhenIdDoesNotMatch() async {
        let json = widgetsJSON(widgets: [
            widgetJSON(id: "widget-abc", type: "popup"),
        ])
        OrttoAPI.fake([
            FetchWidgetsRequest.self => .make(body: json),
        ])

        let response = await fetchWidgets(widgetId: "widget-zzz")  // no match

        XCTAssertTrue(response.widgets.isEmpty, "No widget with the given id should return empty")
    }
}

// MARK: - JSON Fixtures

/// Builds a minimal valid `WidgetsResponse` JSON string.
private func widgetsJSON(
    widgets: [String] = [],
    sessionId: String? = nil
) -> String {
    let widgetsArray = "[\(widgets.joined(separator: ","))]"
    let sessionPart = sessionId.map { ", \"session_id\": \"\($0)\"" } ?? ""
    return """
    {"widgets": \(widgetsArray), "has_logo": false, "enabled_gdpr": false, "country_code": "AU", "cdn_url": "https://cdn.test"\(sessionPart)}
    """
}

/// Builds a minimal valid `Widget` JSON string.
///
/// All non-optional fields are included; optional fields are omitted unless specified.
/// The `expiry` value must be in `"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"` format when provided.
private func widgetJSON(
    id: String,
    type: String,
    expiry: String? = nil
) -> String {
    let expiryPart = expiry.map { ", \"expiry\": \"\($0)\"" } ?? ""
    return """
    {"id": "\(id)", "type": "\(type)", \
    "page": {"selection": "all", "device": "any", "platforms": null}, \
    "where": {"selection": "all"}, \
    "when": {"selection": "immediate", "value": "0"}, \
    "who": {"selection": "all"}, \
    "trigger": {"selection": "auto"}, \
    "frequency": "once", \
    "is_gdpr": false, \
    "style": {}, \
    "html": "", \
    "use_slot": "", \
    "font_urls": [], \
    "has_recaptcha": false\
    \(expiryPart)}
    """
}
