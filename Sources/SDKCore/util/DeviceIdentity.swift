//
//  DeviceIdentity.swift
//
//
//  Created by Mitch Flindell on 6/10/2023.
//

import Foundation

public enum DeviceIdentity {
    public static func getOs() -> String {
        return {
            let osName: String = {
                #if os(iOS)
                    #if targetEnvironment(macCatalyst)
                        return "macOS(Catalyst)"
                    #else
                        return "iOS"
                    #endif
                #elseif os(watchOS)
                    return "watchOS"
                #elseif os(tvOS)
                    return "tvOS"
                #elseif os(macOS)
                    return "macOS"
                #elseif os(Linux)
                    return "Linux"
                #elseif os(Windows)
                    return "Windows"
                #else
                    return "Unknown"
                #endif
            }()

            return osName
        }()
    }

    public static func getVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion

        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    public static func getTrackingQueryItems() -> [URLQueryItem] {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { ptr in
                String(validatingUTF8: ptr)
            }
        }

        let info = Bundle.main.infoDictionary

        return [
            // App Name
            URLQueryItem(name: "an", value: info?["CFBundleIdentifier"] as? String ?? "Unknown"),
            // App Version
            URLQueryItem(name: "av", value: info?["CFBundleShortVersionString"] as? String ?? "Unknown"),
            // Sdk Version
            URLQueryItem(name: "sv", value: version),
            // OS Name
            URLQueryItem(name: "os", value: getOs()),
            // OS Version
            URLQueryItem(name: "ov", value: getVersion()),
            // Device
            URLQueryItem(name: "dc", value: modelCode),
        ]
    }
}
