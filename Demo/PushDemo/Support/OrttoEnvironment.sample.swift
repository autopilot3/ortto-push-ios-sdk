//
//  OrttoEnvironment.sample.swift
//  Ortto iOS SDK Push Demo
//
//  Template for local Ortto configuration. Copy this file to OrttoEnvironment.swift
//  in the same folder, then fill in your values:
//
//      cp PushDemo/Support/OrttoEnvironment.sample.swift \
//         PushDemo/Support/OrttoEnvironment.swift
//
//  OrttoEnvironment.swift is gitignored, so your keys never get committed.
//  (This template file is not compiled — only OrttoEnvironment.swift is.)
//

enum OrttoEnvironment {
    /// Your account's capture endpoint for your region (AU / EU / US) or instance.
    static let apiEndpoint = "https://capture-api-au.ortto.app/"

    /// Fill in the app key for the target you run; leave the other empty.
    static let apnsAppKey = ""
    static let fcmAppKey = ""

    /// Ortto Capture (in-app notifications / widgets) has its OWN data-source key,
    /// separate from the push app key above. Leave empty to stay push-only.
    static let captureDataSourceKey = ""

    /// Optional: set to demo in-app notifications (widgets). Leave empty to stay push-only.
    static let captureJsURL = ""
}
