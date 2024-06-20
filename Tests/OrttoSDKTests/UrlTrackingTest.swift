//
//  UrlTrackingTest.swift
//  
//
//  Created by Mitchell Flindell on 20/6/2024.
//

import Foundation
@testable import OrttoPushMessaging
@testable import OrttoSDKCore
import XCTest

class UrlTrackingTest: XCTestCase {
    
    var mockApiManager: MockApiManager!

    override func setUp() {
        super.setUp()
        mockApiManager = MockApiManager()
        Ortto.initialize(appKey: "api-key", endpoint: "https://ortto.com")
        Ortto.shared.apiManager = mockApiManager
    }

    func testTrackLinkClick() {
        let encodedUrl = "ortto-sdk://example.com/pathname?tracking_url=aHR0cHM6Ly90cmFja2luZy5leGFtcGxlLmNvbS8_cD1leGFtcGxlJnBsdD1pb3MmZT0xMTYxYzUzOThhYzMyY2JiNjI3ZmY1NzU3Y2U0ZWQyNzdjNjkwNTkwZWJhNzBhN2Q2Y2Q5ZDRhMWZkMTc1ZjJhJnNpZD02NjczYTRhZWZlNjllM2E3YWJkM2I4MTU"
        var expectedDecodedUrl = "https://tracking.example.com/?p=example&plt=ios&e=1161c5398ac32cbb627ff5757ce4ed277c690590eba70a7d6cd9d4a1fd175f2a&sid=6673a4aefe69e3a7abd3b815"
        
        var urlComponents = URLComponents(string: expectedDecodedUrl)!
        let mockQueryItems = DeviceIdentity.getTrackingQueryItems()
        urlComponents.queryItems?.append(contentsOf: mockQueryItems)
        expectedDecodedUrl = urlComponents.url!.absoluteString

        let expectation = self.expectation(description: "Completion handler invoked")
        Ortto.shared.trackLinkClick(encodedUrl) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5, handler: nil)

        XCTAssertEqual(mockApiManager.lastTrackingUrl?.absoluteString, expectedDecodedUrl)
    }
}
