//
//  LoginView.swift
//  Ortto iOS SDK Push Demo
//
//  The login screen. Signing in calls Ortto.shared.identify via
//  PushViewModel.signIn(email:).
//

import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: PushViewModel
    @FocusState private var isEmailFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let submittedLoginEmail = viewModel.visibleRememberedLoginEmail.isEmpty ? viewModel.email : viewModel.visibleRememberedLoginEmail
            let logoAreaHeight = max(proxy.size.height - 330, 340)
            let sheetCornerRadius = min(max(proxy.size.width * 0.12, 38), 48)

            ZStack(alignment: .top) {
                LoginTopArtwork(
                    provider: viewModel.activeProvider,
                    logoAreaHeight: logoAreaHeight
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    isEmailFocused = false
                }
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    LoginBottomSheet(
                        email: $viewModel.email,
                        rememberedEmail: viewModel.visibleRememberedLoginEmail,
                        isIdentifying: viewModel.isIdentifying,
                        isContinueDisabled: viewModel.isIdentifying || viewModel.normalizedEmail(submittedLoginEmail).isEmpty,
                        isEmailFocused: $isEmailFocused,
                        bottomInset: proxy.safeAreaInsets.bottom,
                        sheetCornerRadius: sheetCornerRadius,
                        signIn: { submittedEmail in
                            isEmailFocused = false
                            // Ortto SDK: identify happens here. signIn(email:)
                            // calls Ortto.shared.identify with this email —
                            // see PushViewModel.identify(email:reason:).
                            viewModel.signIn(email: submittedEmail)
                        },
                        useAnotherAccount: {
                            isEmailFocused = false
                            withAnimation(.interpolatingSpring(stiffness: 260, damping: 28)) {
                                viewModel.isUsingRememberedLogin = false
                                viewModel.email = ""
                            }
                        }
                    )
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
