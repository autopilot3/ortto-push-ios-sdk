//
//  AppConfiguration.swift
//  Ortto iOS SDK Push Demo
//
//  Reads Ortto configuration from OrttoEnvironment (a plain Swift file copied
//  from OrttoEnvironment.sample.swift). The URL scheme and Firebase plist still
//  come from the bundle.
//

import Foundation

enum AppConfiguration {
    static let firebaseServiceInfoName = "GoogleService-Info"

    static var appKey: String {
        switch appPushProvider {
        case .apns: return OrttoEnvironment.apnsAppKey
        case .fcm: return OrttoEnvironment.fcmAppKey
        }
    }
    static var endpoint: String { OrttoEnvironment.apiEndpoint }
    static var captureJsURL: String { OrttoEnvironment.captureJsURL }
    /// Capture (in-app notifications) uses its own data-source key, separate from the push app key.
    static var captureDataSourceKey: String { OrttoEnvironment.captureDataSourceKey }
    static var hasConfiguredAppKey: Bool { isConfigured(appKey) }
    static var hasConfiguredEndpoint: Bool { isConfigured(endpoint) }
    static var hasConfiguredCaptureJsURL: Bool { isConfigured(captureJsURL) }
    static var hasConfiguredCaptureDataSourceKey: Bool { isConfigured(captureDataSourceKey) }
    static var canInitializeSDK: Bool { hasConfiguredAppKey && hasConfiguredEndpoint }
    /// Capture needs BOTH its own data-source key and the capture JS URL.
    static var canInitializeCapture: Bool { hasConfiguredCaptureDataSourceKey && hasConfiguredCaptureJsURL }

    static var orttoConfigurationFailureDetail: String {
        if !hasConfiguredAppKey {
            return "No Ortto app key. Copy PushDemo/Support/OrttoEnvironment.sample.swift to OrttoEnvironment.swift, set \(appPushProvider.rawValue)AppKey, then rebuild the \(appPushProvider.targetTitle) target."
        }

        return "Set apiEndpoint in PushDemo/Support/OrttoEnvironment.swift, then rebuild the app target."
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

    private static func isConfigured(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lowered = trimmed.lowercased()
        return !lowered.contains("paste_") && !lowered.contains("replace-with") && !lowered.contains("your-")
    }
}
