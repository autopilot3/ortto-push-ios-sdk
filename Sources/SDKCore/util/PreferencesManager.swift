//
//  PreferencesManager.swift
//
//  Used as a local data store
//  Created by Mitch Flindell on 25/11/2022.
//

import Foundation

public protocol PreferencesInterface {
    func getString(_ key: String) -> String?
    func setString(_ value: String, key: String)
    func getObject<T: Codable>(key: String, type: T.Type) -> T?
    func setObject(object: Codable, key: String)
    func clear()
}

public protocol UserStorage {
    var user: UserIdentifier? { get set }
    var session: String? { get set }
}

class OrttoUserStorage: UserStorage {
    private let preferences: PreferencesInterface

    init(_ preferences: PreferencesInterface) {
        self.preferences = preferences
    }

    public var user: UserIdentifier? {
        get {
            preferences.getObject(key: "user", type: UserIdentifier.self)
        }
        set {
            preferences.setObject(object: newValue, key: "user")
        }
    }

    public var session: String? {
        get { preferences.getString("sessionID") }
        set { preferences.setString(newValue!, key: "sessionID") }
    }
}

public class OrttoPreferencesManager: PreferencesInterface {
    private let keyPrefix = "com.ortto.sdk"

    private var defaults: UserDefaults? {
        UserDefaults.standard
    }

    init() {}

    private func prefixedKey(_ key: String) -> String {
        return "\(keyPrefix):\(key)"
    }

    public func getString(_ key: String) -> String? {
        return defaults?.string(forKey: prefixedKey(key))
    }

    public func setString(_ value: String, key: String) {
        defaults?.set(value, forKey: prefixedKey(key))
    }

    public func getObject<T: Codable>(key: String, type _: T.Type) -> T? {
        if let encodedObject = defaults?.object(forKey: prefixedKey(key)) as? Data {
            let decoder = JSONDecoder()
            if let loadedObject = try? decoder.decode(T.self, from: encodedObject) {
                return loadedObject
            }
        }
        return nil
    }

    public func setObject(object: Codable, key: String) {
        let encoder = JSONEncoder()
        do {
            let encoded = try encoder.encode(object)
            defaults?.set(encoded, forKey: prefixedKey(key))
        } catch {
            Ortto.log().info("PreferencesManager@setObject.fail message=\(error.localizedDescription)")
        }
    }

    /**
     Remove all internal data used by SDK
     */
    public func clear() {
        if let defaults = defaults {
            let allKeys = defaults.dictionaryRepresentation().keys
            let sdkKeys = allKeys.filter { $0.hasPrefix(keyPrefix) }
            sdkKeys.forEach { key in
                defaults.removeObject(forKey: key)
            }
        }
    }
}
