//
//  OrttoPreferencesManagerTests.swift
//  
//
//  Created by Mitchell Flindell on 1/8/2024.
//

@testable import OrttoSDKCore
import XCTest

class OrttoPreferencesManagerTests: XCTestCase {

    var preferencesManager: OrttoPreferencesManager!
    var mockUserDefaults: UserDefaults!
    let testSuiteName = "TestUserDefaults"
    let keyPrefix = "com.ortto.sdk"

    override func setUp() {
        super.setUp()
        mockUserDefaults = UserDefaults(suiteName: testSuiteName)!
        preferencesManager = OrttoPreferencesManager()
        swizzleUserDefaults(mockUserDefaults)
    }

    override func tearDown() {
        swizzleUserDefaults(nil)
        UserDefaults().removePersistentDomain(forName: testSuiteName)
        mockUserDefaults = nil
        preferencesManager = nil
        super.tearDown()
    }

    func testSetStringAppliesKeyPrefix() {
        let key = "testKey"
        let value = "testValue"
        
        preferencesManager.setString(value, key: key)
        
        XCTAssertNil(mockUserDefaults.string(forKey: key), "Value should not be set without prefix")
        XCTAssertEqual(mockUserDefaults.string(forKey: "\(keyPrefix):\(key)"), value, "Value should be set with prefix")
    }

    func testGetStringHandlesKeyPrefix() {
        let key = "testKey"
        let value = "testValue"
        
        mockUserDefaults.set(value, forKey: "\(keyPrefix):\(key)")
        
        let retrievedValue = preferencesManager.getString(key)
        XCTAssertEqual(retrievedValue, value, "Retrieved string should match the set value")
    }

    func testSetObjectAppliesKeyPrefix() {
        let key = "testObjectKey"
        let testObject = TestObject(id: 1, name: "Test")
        
        preferencesManager.setObject(object: testObject, key: key)
        
        XCTAssertNil(mockUserDefaults.data(forKey: key), "Object should not be set without prefix")
        XCTAssertNotNil(mockUserDefaults.data(forKey: "\(keyPrefix):\(key)"), "Object should be set with prefix")
    }

    func testGetObjectHandlesKeyPrefix() {
        let key = "testObjectKey"
        let testObject = TestObject(id: 1, name: "Test")
        
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(testObject) {
            mockUserDefaults.set(encoded, forKey: "\(keyPrefix):\(key)")
        }
        
        let retrievedObject: TestObject? = preferencesManager.getObject(key: key, type: TestObject.self)
        XCTAssertEqual(retrievedObject?.id, testObject.id)
        XCTAssertEqual(retrievedObject?.name, testObject.name)
    }

    func testClearRemovesOnlyPrefixedKeys() {
        let prefixedKey1 = "\(keyPrefix):user"
        let prefixedKey2 = "\(keyPrefix):sessionID"
        let nonPrefixedKey = "nonPrefixedKey"
        
        mockUserDefaults.set("testUser", forKey: prefixedKey1)
        mockUserDefaults.set("testSessionID", forKey: prefixedKey2)
        mockUserDefaults.set("someValue", forKey: nonPrefixedKey)
        
        preferencesManager.clear()
        
        XCTAssertNil(mockUserDefaults.string(forKey: prefixedKey1), "Prefixed key should be removed")
        XCTAssertNil(mockUserDefaults.string(forKey: prefixedKey2), "Prefixed key should be removed")
        XCTAssertNotNil(mockUserDefaults.string(forKey: nonPrefixedKey), "Non-prefixed key should not be removed")
    }

    func testNonExistentKeyWithPrefix() {
        let nonExistentKey = "nonExistentKey"
        XCTAssertNil(preferencesManager.getString(nonExistentKey))
        XCTAssertNil(mockUserDefaults.string(forKey: "\(keyPrefix):\(nonExistentKey)"))
    }
}

// Helper structs and functions

struct TestObject: Codable, Equatable {
    let id: Int
    let name: String
}

extension OrttoPreferencesManagerTests {
    func swizzleUserDefaults(_ newUserDefaults: UserDefaults?) {
        let originalSelector = #selector(getter: UserDefaults.standard)
        let swizzledSelector = #selector(getter: UserDefaults.myStandard)

        guard let originalMethod = class_getClassMethod(UserDefaults.self, originalSelector),
              let swizzledMethod = class_getClassMethod(UserDefaults.self, swizzledSelector) else {
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
        UserDefaults.mockStandard = newUserDefaults
    }
}

extension UserDefaults {
    static var mockStandard: UserDefaults?
    
    @objc dynamic class var myStandard: UserDefaults {
        return mockStandard ?? UserDefaults.standard
    }
}
