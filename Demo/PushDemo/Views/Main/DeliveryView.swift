//
//  DeliveryView.swift
//  Ortto iOS SDK Push Demo
//

@preconcurrency import OrttoSDKCore
import SwiftUI
import UIKit

struct DeliveryView: View {
    @Bindable var viewModel: PushViewModel

    @FocusState private var isFCMTokenFocused: Bool
    @FocusState private var isTrackedDeepLinkFocused: Bool
    @FocusState private var isWidgetIDFocused: Bool

    var body: some View {
        List {
            currentStatusSection
            configurationSection
            fcmTokenOverrideSection
            clickTrackingSection
            inAppNotificationsSection
            actionsSection
        }
        .font(AppTypography.sans(.body))
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 78)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done", action: dismissKeyboard)
            }
        }
        .onAppear {
            // Ortto SDK: record this screen view.
            Ortto.shared.screen(AppTab.delivery.screenName)
            viewModel.logScreenView(.delivery)
        }
    }

    private var currentStatusSection: some View {
        Section {
            LabeledContent("Provider", value: viewModel.activeProvider.title)
            LabeledContent("Token") {
                if let currentPushToken = viewModel.currentPushToken {
                    CopyableValue(
                        value: currentPushToken,
                        displayValue: viewModel.short(currentPushToken),
                        isMonospaced: true,
                        copy: viewModel.copyCurrentPushToken
                    )
                } else {
                    Text(viewModel.deliveryTokenStatus)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            LabeledContent("Permission", value: viewModel.permissionStatus)
        } header: {
            Text("Current status")
                .font(AppTypography.sans(.caption, weight: .bold))
        }
        .simultaneousGesture(TapGesture().onEnded { _ in dismissKeyboard() })
    }

    @ViewBuilder
    private var configurationSection: some View {
        if !viewModel.blockingConfigurationIssues.isEmpty {
            Section {
                ConfigurationIssueRows(issues: viewModel.blockingConfigurationIssues)

                Button("View Log") {
                    viewModel.selectedTab = .diagnostics
                }
            } header: {
                Text("Configuration")
                    .font(AppTypography.sans(.caption, weight: .bold))
            }
        }
    }

    @ViewBuilder
    private var fcmTokenOverrideSection: some View {
        if viewModel.activeProvider == .fcm {
            Section {
                TextField("Firebase registration token", text: $viewModel.fcmToken)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .font(.system(.footnote, design: .monospaced))
                    .focused($isFCMTokenFocused)
                    .submitLabel(.done)
                    .onSubmit(dismissKeyboard)
            } header: {
                Text("FCM token override")
                    .font(AppTypography.sans(.caption, weight: .bold))
            } footer: {
                Text("Filled automatically from Firebase Messaging; paste a token only as a fallback.")
                    .font(AppTypography.sans(.footnote))
            }
        }
    }

    private var clickTrackingSection: some View {
        Section {
            TextField("\(AppConfiguration.deepLinkScheme)://campaign?tracking_url=...", text: $viewModel.trackedDeepLink, axis: .vertical)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.system(.footnote, design: .monospaced))
                .focused($isTrackedDeepLinkFocused)
                .lineLimit(2...5)
                .submitLabel(.done)
                .onSubmit(dismissKeyboard)
        } header: {
            Text("Click tracking")
                .font(AppTypography.sans(.caption, weight: .bold))
        } footer: {
            Text("Paste the action deeplink from an Ortto push payload. The automatic tap path calls the same SDK method after the notification response is forwarded.")
                .font(AppTypography.sans(.footnote))
        }
    }

    private var inAppNotificationsSection: some View {
        Section {
            // 1 — Fetch the account's popup widgets to choose from.
            DeliveryActionButton(
                title: viewModel.isLoadingWidgets ? "Loading widgets…" : "Load widgets",
                detail: "Fetch this account's popup widgets so you can tap one to show.",
                tint: AppColor.lilac,
                isLoading: viewModel.isLoadingWidgets,
                status: viewModel.actionStatus(.loadWidgets, fallback: viewModel.currentLoadWidgetsStatus, tone: viewModel.showWidgetTone),
                action: viewModel.runLoadWidgetsAction
            )
            .disabled(viewModel.isLoadingWidgets)

            // 2 — Fetched widgets: tap a row to present it.
            ForEach(viewModel.availableWidgets) { widget in
                Button {
                    dismissKeyboard()
                    viewModel.showWidget(id: widget.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.portrait.on.rectangle.portrait.angled")
                            .font(AppTypography.sans(.title3))
                            .foregroundStyle(AppColor.lilac)
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(widget.id)
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(AppColor.ink)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(widget.type.capitalized)
                                .font(AppTypography.sans(.caption2, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            // 3 — Show by ID: an explicit input with its own Show action.
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    TextField("Enter a widget ID", text: $viewModel.widgetID)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .font(.system(.footnote, design: .monospaced))
                        .focused($isWidgetIDFocused)
                        .submitLabel(.go)
                        .onSubmit {
                            dismissKeyboard()
                            viewModel.runShowWidgetAction()
                        }
                    Button {
                        dismissKeyboard()
                        viewModel.runShowWidgetAction()
                    } label: {
                        Text("Show")
                            .font(AppTypography.sans(.subheadline, weight: .bold))
                            .frame(minWidth: 46)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColor.lilac)
                    .disabled(viewModel.widgetID.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                showWidgetStatusRow
            }
            .padding(.vertical, 2)
        } header: {
            Text("In-app notifications")
                .font(AppTypography.sans(.caption, weight: .bold))
        } footer: {
            Text("Tap Load widgets, then tap a result to present it — or type a widget ID and tap Show. Screen views (sent on each tab) also auto-trigger any widget configured for that screen.")
                .font(AppTypography.sans(.footnote))
        }
        .simultaneousGesture(TapGesture().onEnded { _ in dismissKeyboard() })
    }

    @ViewBuilder
    private var showWidgetStatusRow: some View {
        let status = viewModel.actionStatus(.showWidget, fallback: viewModel.currentShowWidgetStatus, tone: viewModel.showWidgetTone)
        HStack(spacing: 5) {
            Image(systemName: status.tone.symbol)
                .font(.system(size: 10, weight: .bold))
            Text(status.text)
                .font(AppTypography.sans(.caption2, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(status.tone.tint)
    }

    private var actionsSection: some View {
        Section {
            DeliveryActionButton(
                title: viewModel.isIdentifying ? "Identifying contact" : "Identify contact",
                detail: "Attach the remembered email to the Ortto SDK session.",
                tint: AppColor.lilac,
                isLoading: viewModel.isIdentifying,
                status: viewModel.actionStatus(.identify, fallback: viewModel.currentIdentityStatus),
                action: viewModel.runIdentifyAction
            )
            .disabled(viewModel.isIdentifying)

            DeliveryActionButton(
                title: viewModel.registrationActionTitle,
                detail: viewModel.activeProvider == .fcm ? "Request Firebase Messaging registration and forward the FCM token." : "Ask iOS for APNS registration and forward the device token.",
                tint: viewModel.activeProvider == .fcm ? AppColor.orange : AppColor.blue,
                isLoading: viewModel.isRequestingPush,
                status: viewModel.actionStatus(.registerPush, fallback: viewModel.currentRegisterStatus, tone: viewModel.currentRegisterTone),
                action: viewModel.runRegisterPushAction
            )
            .disabled(viewModel.homePushActionDisabled)

            if viewModel.activeProvider == .apns {
                DeliveryActionButton(
                    title: "Log full APNS token",
                    detail: "Write the complete APNS token to the app log and Xcode console.",
                    tint: AppColor.blue,
                    status: viewModel.actionStatus(.logAPNSToken, fallback: viewModel.currentLogAPNSStatus),
                    action: viewModel.runLogAPNSTokenAction
                )
                .disabled(viewModel.apnsToken.isEmpty)
            }

            DeliveryActionButton(
                title: "Redispatch SDK token",
                detail: "Ask the SDK to process the SDK token again.",
                tint: AppColor.green,
                status: viewModel.actionStatus(.redispatch, fallback: viewModel.currentRedispatchStatus),
                action: viewModel.runRedispatchAction
            )
            .disabled(viewModel.sdkToken == nil)

            DeliveryActionButton(
                title: "Track link click",
                detail: "Call Ortto.shared.trackLinkClick with a tracked push-action deeplink.",
                tint: AppColor.blue,
                isLoading: viewModel.isTrackingLinkClick,
                status: viewModel.actionStatus(.trackLink, fallback: viewModel.currentTrackLinkStatus, tone: viewModel.currentTrackLinkTone),
                action: viewModel.runTrackLinkAction
            )
            .disabled(viewModel.isTrackingLinkClick)

            DeliveryActionButton(
                title: "Refresh permission",
                detail: "Read the latest notification permission state from iOS.",
                tint: AppColor.lilac,
                status: viewModel.actionStatus(.refreshPermission, fallback: viewModel.currentPermissionStatus),
                action: viewModel.runRefreshPermissionAction
            )
        } header: {
            Text("Actions")
                .font(AppTypography.sans(.caption, weight: .bold))
        }
        .simultaneousGesture(TapGesture().onEnded { _ in dismissKeyboard() })
    }

    private func dismissKeyboard() {
        isFCMTokenFocused = false
        isTrackedDeepLinkFocused = false
        isWidgetIDFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
