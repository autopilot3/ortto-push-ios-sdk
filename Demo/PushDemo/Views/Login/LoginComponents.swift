//
//  LoginComponents.swift
//  Ortto iOS SDK Push Demo
//
//  Login and remembered-contact views for the Ortto iOS SDK demo app.
//

import SwiftUI

struct ContinuousLoginBackground: View {
    let provider: PushProvider
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                OrganicLoginField(provider: provider, time: time)

                backgroundVeil
            }
            .animation(.easeInOut(duration: 0.65), value: provider)
        }
    }

    private var backgroundVeil: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.02)
            : Color.white.opacity(0.08)
    }
}

struct LoginTopArtwork: View {
    let provider: PushProvider
    let logoAreaHeight: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 16) {
                Text("Push Demo")
                    .font(AppTypography.display(size: 58, weight: .bold, relativeTo: .largeTitle))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .shadow(color: AppColor.ink.opacity(0.22), radius: 14, x: 0, y: 7)

                LockedPushProviderBadge(provider: provider)
                    .offset(x: -8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: logoAreaHeight, alignment: .center)
            .padding(.horizontal, 28)
        }
        .clipped()
    }
}

struct OrganicLoginField: View {
    let provider: PushProvider
    let time: TimeInterval
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if #available(iOS 18.0, *) {
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: meshPoints,
                    colors: meshColors,
                    background: meshBackground,
                    smoothsColors: true
                )
            } else {
                LinearGradient(
                    colors: colorScheme == .dark ? meshColors : provider.loginBaseColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            FluidHighlight(progress: CGFloat((sin(time * 0.42) + 1) / 2), provider: provider)
                .fill(highlightColor)
                .blur(radius: 18)
                .blendMode(.softLight)
        }
    }

    private var meshPoints: [SIMD2<Float>] {
        let t = Float(time)
        return [
            SIMD2<Float>(0.00, 0.00),
            SIMD2<Float>(0.48 + 0.12 * sin(t * 0.36), 0.00),
            SIMD2<Float>(1.00, 0.00),
            SIMD2<Float>(0.00, 0.46 + 0.12 * cos(t * 0.31)),
            SIMD2<Float>(0.50 + 0.18 * sin(t * 0.28), 0.50 + 0.16 * cos(t * 0.25)),
            SIMD2<Float>(1.00, 0.54 + 0.13 * sin(t * 0.33)),
            SIMD2<Float>(0.00, 1.00),
            SIMD2<Float>(0.52 + 0.13 * cos(t * 0.27), 1.00),
            SIMD2<Float>(1.00, 1.00)
        ]
    }

    private var meshColors: [Color] {
        if colorScheme == .dark {
            switch provider {
            case .apns:
                return [
                    Color(red: 0.03, green: 0.18, blue: 0.25),
                    Color(red: 0.04, green: 0.44, blue: 0.48),
                    Color(red: 0.20, green: 0.18, blue: 0.52),
                    Color(red: 0.00, green: 0.34, blue: 0.38),
                    Color(red: 0.06, green: 0.70, blue: 0.74),
                    Color(red: 0.48, green: 0.30, blue: 0.82),
                    Color(red: 0.03, green: 0.11, blue: 0.17),
                    Color(red: 0.10, green: 0.46, blue: 0.55),
                    Color(red: 0.25, green: 0.18, blue: 0.58)
                ]
            case .fcm:
                return [
                    Color(red: 0.20, green: 0.14, blue: 0.48),
                    Color(red: 0.58, green: 0.18, blue: 0.46),
                    Color(red: 0.70, green: 0.36, blue: 0.06),
                    Color(red: 0.38, green: 0.16, blue: 0.52),
                    Color(red: 0.92, green: 0.36, blue: 0.08),
                    Color(red: 0.26, green: 0.35, blue: 0.22),
                    Color(red: 0.46, green: 0.18, blue: 0.40),
                    Color(red: 0.30, green: 0.18, blue: 0.64),
                    Color(red: 0.74, green: 0.50, blue: 0.08)
                ]
            }
        }

        switch provider {
        case .apns:
            return [
                Color(red: 0.18, green: 0.88, blue: 0.92),
                Color(red: 0.94, green: 1.00, blue: 1.00),
                Color(red: 0.74, green: 0.56, blue: 1.00),
                Color(red: 0.12, green: 0.92, blue: 0.88),
                Color(red: 0.38, green: 0.92, blue: 0.96),
                Color(red: 0.69, green: 0.42, blue: 1.00),
                Color(red: 0.70, green: 0.98, blue: 0.99),
                Color(red: 1.00, green: 0.84, blue: 0.95),
                Color(red: 0.63, green: 0.46, blue: 1.00)
            ]
        case .fcm:
            return [
                Color(red: 0.76, green: 0.54, blue: 1.00),
                Color(red: 1.00, green: 0.58, blue: 0.72),
                Color(red: 1.00, green: 0.90, blue: 0.34),
                Color(red: 0.96, green: 0.58, blue: 1.00),
                Color(red: 1.00, green: 0.70, blue: 0.18),
                Color(red: 0.96, green: 1.00, blue: 0.93),
                Color(red: 1.00, green: 0.64, blue: 0.76),
                Color(red: 0.70, green: 0.42, blue: 1.00),
                Color(red: 1.00, green: 0.88, blue: 0.36)
            ]
        }
    }

    private var meshBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.05, green: 0.06, blue: 0.10)
            : Color.white
    }

    private var highlightColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.16)
            : Color.white.opacity(0.30)
    }
}

struct FluidHighlight: Shape {
    let progress: CGFloat
    let provider: PushProvider

    func path(in rect: CGRect) -> Path {
        let drift = provider == .apns ? progress : 1 - progress
        let centerX = rect.width * (0.22 + 0.56 * drift)
        let centerY = rect.height * (0.20 + 0.18 * sin(drift * .pi * 2))
        let width = rect.width * 0.82
        let height = rect.height * 0.34
        let base = CGRect(
            x: centerX - width / 2,
            y: centerY - height / 2,
            width: width,
            height: height
        )

        var path = Path()
        path.move(to: CGPoint(x: base.minX, y: base.midY))
        path.addCurve(
            to: CGPoint(x: base.midX, y: base.minY),
            control1: CGPoint(x: base.minX + width * 0.12, y: base.minY + height * 0.12),
            control2: CGPoint(x: base.minX + width * 0.32, y: base.minY - height * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: base.maxX, y: base.midY),
            control1: CGPoint(x: base.minX + width * 0.72, y: base.minY + height * 0.08),
            control2: CGPoint(x: base.maxX - width * 0.08, y: base.minY + height * 0.22)
        )
        path.addCurve(
            to: CGPoint(x: base.midX, y: base.maxY),
            control1: CGPoint(x: base.maxX - width * 0.18, y: base.maxY + height * 0.08),
            control2: CGPoint(x: base.minX + width * 0.72, y: base.maxY + height * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: base.minX, y: base.midY),
            control1: CGPoint(x: base.minX + width * 0.24, y: base.maxY - height * 0.04),
            control2: CGPoint(x: base.minX - width * 0.08, y: base.maxY - height * 0.24)
        )
        return path
    }
}

struct LoginBottomSheet: View {
    @Binding var email: String
    let rememberedEmail: String
    let isIdentifying: Bool
    let isContinueDisabled: Bool
    let isEmailFocused: FocusState<Bool>.Binding
    let bottomInset: CGFloat
    let sheetCornerRadius: CGFloat
    let signIn: (String) -> Void
    let useAnotherAccount: () -> Void

    private var cleanedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanedRememberedEmail: String {
        rememberedEmail.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasSavedAccount: Bool {
        !cleanedRememberedEmail.isEmpty
    }

    private var submittedEmail: String {
        hasSavedAccount ? cleanedRememberedEmail : cleanedEmail
    }

    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 24) {
                Text(hasSavedAccount ? "Jump back in!" : "Sign in")
                    .font(AppTypography.sans(size: 34, weight: .bold, relativeTo: .largeTitle))
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                VStack(spacing: 18) {
                    if hasSavedAccount {
                        LoginSavedAccount(email: cleanedRememberedEmail)
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    } else {
                        LoginEmailField(email: $email, isFocused: isEmailFocused)
                            .onSubmit {
                                guard !isContinueDisabled else { return }
                                signIn(submittedEmail)
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }

                    Button {
                        signIn(submittedEmail)
                    } label: {
                        HStack(spacing: 10) {
                            if isIdentifying {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            }

                            Text(isIdentifying ? "Logging in" : (hasSavedAccount ? "Continue" : "Sign in"))
                                .font(AppTypography.sans(.headline, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .loginGlassProminentButton()
                    .disabled(isContinueDisabled)

                    if hasSavedAccount {
                        Button {
                            useAnotherAccount()
                        } label: {
                            Text("Sign in with another account")
                                .font(AppTypography.sans(.subheadline, weight: .bold))
                                .foregroundStyle(AppColor.ink.opacity(0.54))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                        .disabled(isIdentifying)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }
                }
                .animation(.interpolatingSpring(stiffness: 260, damping: 28), value: hasSavedAccount)
            }
            .frame(maxWidth: 520, alignment: .leading)
        }
        .padding(.top, 38)
        .padding(.horizontal, 28)
        .padding(.bottom, bottomInset + 24)
        .frame(maxWidth: .infinity)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isEmailFocused.wrappedValue = false
                }
                .font(AppTypography.sans(.body, weight: .bold))
            }
        }
        .background {
            LoginSheetShape(radius: sheetCornerRadius)
                .fill(AppColor.surface)
                .shadow(color: AppColor.ink.opacity(0.08), radius: 20, x: 0, y: -8)
        }
    }
}

struct LockedPushProviderBadge: View {
    let provider: PushProvider

    var body: some View {
        Label(provider.rawValue, systemImage: "lock.fill")
            .font(AppTypography.sans(.caption, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.18), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.30), lineWidth: 1)
            }
            .shadow(color: AppColor.ink.opacity(0.18), radius: 8, x: 0, y: 3)
            .accessibilityLabel("Push provider")
            .accessibilityValue("\(provider.rawValue) locked")
    }
}


struct LoginSavedAccount: View {
    let email: String

    var body: some View {
        VStack(spacing: 14) {
            Text(initials)
                .font(AppTypography.display(size: 38, weight: .medium, relativeTo: .title))
                .foregroundStyle(.white)
                .frame(width: 92, height: 92)
                .background(
                    LinearGradient(
                        colors: [AppColor.lilac, Color(red: 0.58, green: 0.22, blue: 0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )

            VStack(spacing: 4) {
                Text(displayName)
                    .font(AppTypography.sans(.title3, weight: .medium))
                    .foregroundStyle(AppColor.ink)
                Text(email)
                    .font(AppTypography.sans(.body))
                    .foregroundStyle(AppColor.ink.opacity(0.62))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var displayName: String {
        let name = email.split(separator: "@").first.map(String.init) ?? email
        let formatted = name
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "+", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + String($0.dropFirst()) }
            .joined(separator: " ")
        return formatted.isEmpty ? email : formatted
    }

    private var initials: String {
        let parts = displayName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }.map(String.init)
        if !letters.isEmpty {
            return letters.joined().uppercased()
        }
        return String(email.prefix(2)).uppercased()
    }
}

struct LoginEmailField: View {
    @Binding var email: String
    let isFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Email")
                .font(AppTypography.sans(.subheadline, weight: .bold))
                .foregroundStyle(AppColor.ink)

            ZStack(alignment: .leading) {
                if email.isEmpty {
                    Text("Email address")
                        .font(AppTypography.sans(.body, weight: .medium))
                        .foregroundStyle(AppColor.ink.opacity(0.28))
                        .padding(.horizontal, 18)
                        .allowsHitTesting(false)
                }

                TextField("", text: $email)
                    .focused(isFocused)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .submitLabel(.go)
                    .font(AppTypography.sans(.body, weight: .medium))
                    .foregroundStyle(AppColor.ink)
                    .tint(AppColor.lilac)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 18)
            }
            .frame(height: 58)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture {
                isFocused.wrappedValue = true
            }
            .loginInputGlass(cornerRadius: 8)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isFocused.wrappedValue ? AppColor.lilac : AppColor.ink.opacity(0.22),
                        lineWidth: isFocused.wrappedValue ? 2 : 1
                    )
            }

            Text("We'll log you in with your Ortto demo account.")
                .font(AppTypography.sans(.footnote))
                .foregroundStyle(AppColor.ink.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct LoginSheetShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(radius, rect.width / 2, rect.height / 2)
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + r, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + r),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
