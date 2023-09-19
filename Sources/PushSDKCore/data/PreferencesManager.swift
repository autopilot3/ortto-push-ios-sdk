//
//  PreferencesManager.swift
//  
//  Used as a local data store
//  Created by Mitch Flindell on 25/11/2022.
//

import Foundation

internal class PreferencesManager {
    
    internal var defaults: UserDefaults
    internal var sessionID: String?
    internal var user: UserIdentifier?
    internal var permission: PushPermission = PushPermission.Automatic
    internal var token: PushToken?
    
    internal init () {
        defaults = UserDefaults.standard
        sessionID = defaults.string(forKey: "sessionID")
        
        if let encodedUser = defaults.object(forKey: "user") as? Data {
            let decoder = JSONDecoder()
            if let loadedUser = try? decoder.decode(UserIdentifier.self, from: encodedUser) {
                self.user = loadedUser
            }
        }
        
        if let defaultPermission = defaults.string(forKey: "pushPermission") {
            permission = PushPermission.init(rawValue: defaultPermission)!
        }
        
        if let encodedToken = defaults.object(forKey: "token") as? Data {
            let decoder = JSONDecoder()
            if let loadedToken = try? decoder.decode(PushToken.self, from: encodedToken) {
                self.token = loadedToken
            }
        }
    }
        
    /**
     Remove all internal data used by SDK
     */
    internal func clearAll() {
        UserDefaults.resetStandardUserDefaults()
    }
    
    /**
     Check if we have a push token saved
     */
    internal func hasToken() -> Bool {
        guard token != nil else {
            return false
        }
        
        return true
    }
        
    /**
     Set the push notification authorization token locally
     */
    internal func setToken(_ token: PushToken) {
        self.token = token 
        let encoder = JSONEncoder()
        do {
            let encoded = try encoder.encode(token)
            defaults.set(encoded, forKey: "token")
        } catch let error {
            Ortto.log().info("PreferencesManager@setToken.fail message=\(error.localizedDescription)")
        }
    }
        
    /**
     Set the user session identifier
     */
    internal func setSessionID(_ sessionID: String) -> Void {
        self.sessionID = sessionID
        defaults.set(sessionID, forKey: "sessionID")
    }
        
    /**
     Set the user push notification permission flag
     */
    internal func setPermission(_ permission: PushPermission) -> Void {
        self.permission = permission;
        defaults.set(permission.rawValue, forKey: "pushPermission")
    }
            
    /**
     Set the current identify
     */
    internal func setUser(_ user: UserIdentifier) {
        let encoder = JSONEncoder()
        do {
            let encoded = try encoder.encode(user)
            defaults.set(encoded, forKey: "user")
        } catch let error {
            Ortto.log().info("PreferencesManager@setUser.fail message=\(error.localizedDescription)")
        }
    }
}
