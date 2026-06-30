//
//  OrttoTestSupport.swift
//  Shared test scaffolding: global-state isolation, an in-memory API manager, and a
//  thread-safe counter for the concurrency tests.
//

import Foundation
@testable import OrttoSDKCore
import XCTest

/// Base class for tests that mutate global Ortto identity state. Each test gets a fresh,
/// cleared `OrttoPreferencesManager` + `OrttoUserStorage`; the original preferences, user
/// storage, and API manager are restored on teardown so no test leaks session/user state
/// into the next one.
class OrttoIsolatedTestCase: OrttoTestCase {

    /// The fresh, cleared preferences installed for the duration of the current test.
    private(set) var preferences: OrttoPreferencesManager!

    private var savedPreferences: PreferencesInterface!
    private var savedUserStorage: UserStorage!
    private var savedApiManager: ApiManagerInterface!
    private var savedQueue: OrttoRequestQueue!

    override func setUp() {
        super.setUp()

        savedPreferences = Ortto.shared.preferences
        savedUserStorage = Ortto.shared.userStorage
        savedApiManager = Ortto.shared.apiManager
        savedQueue = Ortto.shared.requestQueue

        preferences = OrttoPreferencesManager()
        preferences.clear()
        Ortto.shared.preferences = preferences
        Ortto.shared.userStorage = OrttoUserStorage(preferences)
        Ortto.shared.requestQueue = OrttoRequestQueue() // fresh lane so no op leaks between tests
    }

    override func tearDown() {
        Ortto.shared.preferences.clear()
        Ortto.shared.requestQueue = savedQueue
        Ortto.shared.apiManager = savedApiManager
        Ortto.shared.userStorage = savedUserStorage
        Ortto.shared.preferences = savedPreferences
        super.tearDown()
    }
}

/// A minimal thread-safe counter for the concurrency tests.
final class AtomicCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    /// The current value.
    var value: Int {
        lock.lock(); defer { lock.unlock() }
        return count
    }

    /// Atomically increments and returns the new value.
    @discardableResult
    func increment() -> Int {
        lock.lock(); defer { lock.unlock() }
        count += 1
        return count
    }
}
