//
//  RootView.swift
//  Ortto iOS SDK Push Demo
//
//  App shell: shows LoginView until an email is signed in, then MainTabView.
//  Also hosts the cross-screen background fade and the action toast overlay.
//

import SwiftUI

struct RootView: View {
    @State private var viewModel = PushViewModel()

    var body: some View {
        ZStack {
            appBackground

            if viewModel.isSignedIn {
                MainTabView(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                LoginView(viewModel: viewModel)
                    .transition(.opacity)
            }

            if viewModel.isSignedIn, let actionToast = viewModel.actionToast {
                VStack {
                    Spacer()
                    SDKToastView(toast: actionToast)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 74)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(3)
            }
        }
        .tint(AppColor.ink)
        .animation(.easeInOut(duration: 0.34), value: viewModel.isSignedIn)
        .animation(.interpolatingSpring(stiffness: 260, damping: 26), value: viewModel.actionToast)
        .onAppear {
            viewModel.prepareInitialState()

            // Ortto SDK: push registration starts here on first open — the
            // notification permission prompt, then
            // UIApplication.registerForRemoteNotifications(). iOS delivers the
            // device token to APNSAppDelegate/FCMAppDelegate, which forwards
            // it to PushMessaging.shared.
            viewModel.performFirstOpenPushIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .logEntry)) { note in
            viewModel.receiveLogEntry(note)
        }
        // Ortto SDK: notification tap/action deeplinks land here. The SDK opens
        // the action link with UIApplication.shared.open(_:); iOS routes the
        // app's own URL scheme (ortto-demo-fcm/-apns) back into onOpenURL.
        .onOpenURL { url in
            viewModel.handleDeepLink(url)
        }
        // Default (body-tap) action confirmation modal.
        .alert(
            "Open from notification?",
            isPresented: Binding(
                get: { viewModel.deepLinkPrompt != nil },
                set: { if !$0 { viewModel.dismissDeepLinkPrompt() } }
            ),
            presenting: viewModel.deepLinkPrompt
        ) { _ in
            Button("Open Delivery") { viewModel.confirmDeepLinkPrompt() }
            Button("Cancel", role: .cancel) { viewModel.dismissDeepLinkPrompt() }
        } message: { prompt in
            Text("You tapped a push notification.\n\(prompt.link)")
        }
    }

    private var appBackground: some View {
        ZStack {
            // The SwiftUI gradient renders immediately; the Paper Shaders mesh
            // fades in over it once the WebGL canvas draws its first frame.
            ZStack {
                ContinuousLoginBackground(provider: viewModel.activeProvider)
                PaperShaderBackground(provider: viewModel.activeProvider)
            }
            .opacity(viewModel.isSignedIn ? 0 : 1)

            Color(uiColor: .systemGroupedBackground)
                .opacity(viewModel.isSignedIn && viewModel.selectedTab != .diagnostics ? 1 : 0)

            MatrixBackdrop()
                .opacity(viewModel.isSignedIn && viewModel.selectedTab == .diagnostics ? 1 : 0)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.42), value: viewModel.isSignedIn)
        .animation(.easeInOut(duration: 0.22), value: viewModel.selectedTab)
    }
}

#Preview {
    RootView()
}
