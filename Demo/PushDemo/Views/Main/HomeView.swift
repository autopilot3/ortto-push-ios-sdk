//
//  HomeView.swift
//  Ortto iOS SDK Push Demo
//

@preconcurrency import OrttoSDKCore
import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: PushViewModel

    var body: some View {
        List {
            contactSection
            configurationSection
            deviceSection
        }
        .font(AppTypography.sans(.body))
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 78)
        }
        .onAppear {
            // Ortto SDK: record this screen view.
            Ortto.shared.screen(AppTab.home.screenName)
            viewModel.logScreenView(.home)
        }
    }

    private var contactSection: some View {
        Section {
            LabeledContent("Email") {
                CopyableValue(value: viewModel.signedInEmail) {
                    viewModel.copyToClipboard(viewModel.signedInEmail, label: "email")
                }
            }

            LabeledContent("Remembered") {
                Text(viewModel.rememberedContactValue)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            LabeledContent("SDK session", value: viewModel.sessionID == nil ? "Anonymous" : "Identified")

            ModalRowButton(title: "Technical Details") {
                viewModel.isShowingTechnicalDetails = true
            }
        } header: {
            Text("Contact")
                .font(AppTypography.sans(.caption, weight: .bold))
        }
    }

    @ViewBuilder
    private var configurationSection: some View {
        if !viewModel.blockingConfigurationIssues.isEmpty {
            Section {
                ConfigurationIssueRows(issues: viewModel.blockingConfigurationIssues)

                Button {
                    viewModel.selectedTab = .diagnostics
                } label: {
                    Text("View Log")
                }
            } header: {
                Text("Configuration")
                    .font(AppTypography.sans(.caption, weight: .bold))
            }
        }
    }

    private var deviceSection: some View {
        Section {
            LabeledContent("Provider", value: viewModel.activeProvider.title)
            LabeledContent("Status", value: viewModel.currentPushToken == nil ? "Not registered" : "Registered")
            LabeledContent("Permission", value: viewModel.permissionStatus)
            LabeledContent("iOS registration", value: viewModel.remoteRegistrationStatus.hasPrefix("registered") ? "Registered" : "Not registered")

            if let currentPushToken = viewModel.currentPushToken {
                LabeledContent("Token") {
                    CopyableValue(
                        value: currentPushToken,
                        displayValue: viewModel.short(currentPushToken),
                        isMonospaced: true,
                        copy: viewModel.copyCurrentPushToken
                    )
                }
                .contextMenu {
                    Button("Copy Token", action: viewModel.copyCurrentPushToken)
                }
            } else {
                LabeledContent("Token") {
                    Text(viewModel.pushTokenPlaceholder)
                        .foregroundStyle(viewModel.homePushActionTint)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }

                // Ortto SDK: push registration — permission prompt, then
                // UIApplication.registerForRemoteNotifications(); the token
                // lands in the app delegate and is forwarded to
                // PushMessaging.shared.
                Button(action: viewModel.runRegisterPushAction) {
                    HStack {
                        Text(viewModel.registrationActionTitle)
                        Spacer()
                        if viewModel.isRequestingPush {
                            ProgressView()
                        }
                    }
                }
                .disabled(viewModel.homePushActionDisabled)
            }
        } header: {
            Text("Device")
                .font(AppTypography.sans(.caption, weight: .bold))
        } footer: {
            Text(viewModel.activeProvider == .fcm ? "Firebase Messaging provides the registration token after APNS is attached." : "APNS provides the device token after iOS registration completes.")
                .font(AppTypography.sans(.footnote))
        }
    }
}
