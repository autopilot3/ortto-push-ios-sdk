//
//  PreferencesManager.swift
//
//  Used as a local data store
//  Created by Mitch Flindell on 25/11/2022.
//

import Foundation

class PreferencesManager {
    var defaults: UserDefaults
    var sessionID: String?
    var user: UserIdentifier?
    var permission: PushPermission = .Automatic
    var token: PushToken?

    init() {
        defaults = UserDefaults.standard
        sessionID = defaults.string(forKey: "sessionID")

        if let encodedUser = defaults.object(forKey: "user") as? Data {
            let decoder = JSONDecoder()
            if let loadedUser = try? decoder.decode(UserIdentifier.self, from: encodedUser) {
                user = loadedUser
            }
        }

        if let defaultPermission = defaults.string(forKey: "pushPermission") {
            permission = PushPermission(rawValue: defaultPermission)!
        }

        if let encodedToken = defaults.object(forKey: "token") as? Data {
            let decoder = JSONDecoder()
            if let loadedToken = try? decoder.decode(PushToken.self, from: encodedToken) {
                token = loadedToken
            }
        }
    }

    /**
     Remove all internal data used by SDK
     */
    func clearAll() {
        UserDefaults.resetStandardUserDefaults()
    }

    /**
     Check if we have a push token saved
     */
    func hasToken() -> Bool {
        guard token != nil else {
            return false
        }

        return true
    }

    /**
     Set the push notification authorization token locally
     */
    func setToken(_ token: PushToken) {
        self.token = token
        let encoder = JSONEncoder()
        do {
            let encoded = try encoder.encode(token)
            defaults.set(encoded, forKey: "token")
        } catch {
            Ortto.log().info("PreferencesManager@setToken.fail message=\(error.localizedDescription)")
        }
    }

    /**
     Set the user session identifier
     */
    func setSessionID(_ sessionID: String) {
        self.sessionID = sessionID
        defaults.set(sessionID, forKey: "sessionID")
    }

    /**
     Set the user push notification permission flag
     */
    func setPermission(_ permission: PushPermission) {
        self.permission = permission
        defaults.set(permission.rawValue, forKey: "pushPermission")
    }

    /**
     Set the current identify
     */
    func setUser(_ user: UserIdentifier) {
        let encoder = JSONEncoder()
        do {
            let encoded = try encoder.encode(user)
            defaults.set(encoded, forKey: "user")
        } catch {
            Ortto.log().info("PreferencesManager@setUser.fail message=\(error.localizedDescription)")
        }
    }
}
