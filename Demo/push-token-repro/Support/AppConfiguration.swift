//
//  AppConfiguration.swift
//  Ortto iOS SDK Push Demo
//

import Foundation

enum AppConfiguration {
    private static let plistKey = "OrttoAppConfiguration"
    static let firebaseServiceInfoName = "GoogleService-Info"

    static var appKey: String { configurationString("AppKey") }
    static var endpoint: String { configurationString("Endpoint") }
    static var captureJsURL: String { configurationString("CaptureJsURL") }
    static var hasConfiguredAppKey: Bool { isConfigured(appKey) }
    static var hasConfiguredEndpoint: Bool { isConfigured(endpoint) }
    static var hasConfiguredCaptureJsURL: Bool { isConfigured(captureJsURL) }
    static var canInitializeSDK: Bool { hasConfiguredAppKey && hasConfiguredEndpoint }

    static var orttoConfigurationFailureDetail: String {
        if !hasConfiguredAppKey {
            return "No Ortto app key. Copy push-token-repro/Configurations/Local.xcconfig.example to Local.xcconfig, set ORTTO_\(appPushProvider.rawValue.uppercased())_APP_KEY, then rebuild the \(appPushProvider.targetTitle) target."
        }

        return "Set ORTTO_API_ENDPOINT in push-token-repro/Configurations/Local.xcconfig or BuildDefaults.xcconfig, then rebuild the app target."
    }

    static var deepLinkScheme: String {
        urlSchemes.first { scheme in
            !scheme.isEmpty && !scheme.hasPrefix("$(")
        } ?? ""
    }

    static var hasFirebaseServiceInfo: Bool {
        Bundle.main.path(forResource: firebaseServiceInfoName, ofType: "plist") != nil
    }

    static var firebaseServiceInfoFailureDetail: String {
        "\(firebaseServiceInfoName).plist is not included in this app target. FCM cannot configure Firebase Messaging or mint a real registration token until it is added and the app is rebuilt."
    }

    private static var urlSchemes: [String] {
        let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        return urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
    }

    private static var plist: [String: Any] {
        Bundle.main.object(forInfoDictionaryKey: plistKey) as? [String: Any] ?? [:]
    }

    private static func configurationString(_ key: String) -> String {
        plist[key] as? String ?? ""
    }

    private static func isConfigured(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return false }
        let lowered = trimmed.lowercased()
        return !lowered.contains("paste_") && !lowered.contains("replace-with")
    }
}
