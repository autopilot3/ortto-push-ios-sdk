//
//  TechnicalDetailsView.swift
//  Ortto iOS SDK Push Demo
//

import SwiftUI

struct TechnicalDetailsView: View {
    @ObservedObject var viewModel: PushViewModel

    var body: some View {
        List {
            sdkSection
            sessionSection
            notificationSection
            checksSection
        }
        .font(AppTypography.sans(.body))
        .listStyle(.insetGrouped)
    }

    private var sdkSection: some View {
        Section {
            LabeledContent("Target", value: appPushProvider.targetTitle)
            LabeledContent("Endpoint") {
                CopyableValue(value: AppConfiguration.endpoint) {
                    viewModel.copyToClipboard(AppConfiguration.endpoint, label: "endpoint")
                }
            }
            LabeledContent("App key", value: AppConfiguration.hasConfiguredAppKey ? "Configured" : "Missing")
            LabeledContent("Push package", value: viewModel.activeProvider == .fcm ? "OrttoPushMessagingFCM" : "OrttoPushMessagingAPNS")
            LabeledContent("Firebase config", value: firebaseConfigStatus)
        } header: {
            Text("SDK")
                .font(AppTypography.sans(.caption, weight: .bold))
        }
    }

    private var sessionSection: some View {
        Section {
            LabeledContent("Session") {
                if let sessionID = viewModel.sessionID {
                    CopyableValue(
                        value: sessionID,
                        displayValue: viewModel.short(sessionID),
                        isMonospaced: true,
                        copy: viewModel.copySessionToken
                    )
                } else {
                    Text("None")
                }
            }
            LabeledContent("SDK token type", value: viewModel.sdkTokenType?.uppercased() ?? "None")
            LabeledContent("SDK token") {
                if let sdkToken = viewModel.sdkToken {
                    CopyableValue(
                        value: sdkToken,
                        displayValue: viewModel.short(sdkToken),
                        isMonospaced: true
                    ) {
                        viewModel.copyToClipboard(sdkToken, label: "SDK token")
                    }
                } else {
                    Text("None")
                }
            }
        } header: {
            Text("Session")
                .font(AppTypography.sans(.caption, weight: .bold))
        }
    }

    private var notificationSection: some View {
        Section {
            LabeledContent("APNS environment", value: "development / sandbox")
            LabeledContent("APNS topic") {
                CopyableValue(value: apnsTopic) {
                    viewModel.copyToClipboard(apnsTopic, label: "APNS topic")
                }
            }
            LabeledContent("Deep link scheme", value: AppConfiguration.deepLinkScheme)
            LabeledContent("App delegate source", value: "\(viewModel.activeProvider.rawValue)AppDelegate.swift")
        } header: {
            Text("Notifications")
                .font(AppTypography.sans(.caption, weight: .bold))
        }
    }

    @ViewBuilder
    private var checksSection: some View {
        if !viewModel.configurationIssues.isEmpty {
            Section {
                ConfigurationIssueRows(issues: viewModel.configurationIssues)
            } header: {
                Text("Checks")
                    .font(AppTypography.sans(.caption, weight: .bold))
            }
        }
    }

    private var firebaseConfigStatus: String {
        guard viewModel.activeProvider == .fcm else { return "Not required" }
        return AppConfiguration.hasFirebaseServiceInfo
            ? "\(AppConfiguration.firebaseServiceInfoName).plist bundled"
            : "\(AppConfiguration.firebaseServiceInfoName).plist missing"
    }

    private var apnsTopic: String {
        Bundle.main.bundleIdentifier ?? "unknown"
    }
}
