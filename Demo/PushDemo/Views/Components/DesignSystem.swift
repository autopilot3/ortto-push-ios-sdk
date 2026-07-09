//
//  DesignSystem.swift
//  Ortto iOS SDK Push Demo
//
//  Shared visual styling and controls for the Ortto iOS SDK demo app.
//

import SwiftUI
import UIKit

enum AppColor {
    static let ink = adaptive(
        light: UIColor(red: 0.05, green: 0.07, blue: 0.09, alpha: 1.0),
        dark: UIColor(red: 0.94, green: 0.96, blue: 0.98, alpha: 1.0)
    )
    static let blue = Color(red: 0.00, green: 0.77, blue: 0.80)
    static let green = Color(red: 0.00, green: 0.76, blue: 0.62)
    static let coral = Color(red: 1.00, green: 0.35, blue: 0.49)
    static let orange = Color(red: 1.00, green: 0.60, blue: 0.00)
    static let yellow = Color(red: 1.00, green: 0.82, blue: 0.22)
    static let lilac = Color(red: 0.55, green: 0.24, blue: 1.00)
    static let surface = adaptive(
        light: UIColor.white,
        dark: UIColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 1.0)
    )
    static let inputSurface = adaptive(
        light: UIColor(white: 1.0, alpha: 0.84),
        dark: UIColor(red: 0.18, green: 0.19, blue: 0.22, alpha: 0.92)
    )
    static let inputSurfaceTint = adaptive(
        light: UIColor(white: 1.0, alpha: 0.48),
        dark: UIColor(red: 0.30, green: 0.32, blue: 0.38, alpha: 0.52)
    )
    static let groupBorder = adaptive(
        light: UIColor.black.withAlphaComponent(0.13),
        dark: UIColor.white.withAlphaComponent(0.13)
    )

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

enum AppTypography {
    enum FaceWeight {
        case regular
        case medium
        case bold
    }

    static func display(
        size: CGFloat,
        weight: FaceWeight = .bold,
        relativeTo textStyle: Font.TextStyle = .title
    ) -> Font {
        font(
            names: canvaDisplayNames(for: weight) + fallbackDisplayNames(for: weight),
            size: size,
            relativeTo: textStyle,
            fallback: .system(size: size, weight: systemWeight(for: weight), design: .default)
        )
    }

    static func sans(
        _ textStyle: Font.TextStyle,
        weight: FaceWeight = .regular
    ) -> Font {
        font(
            names: canvaSansNames(for: weight) + fallbackSansNames(for: weight),
            size: defaultSize(for: textStyle),
            relativeTo: textStyle,
            fallback: .system(textStyle, design: .default).weight(systemWeight(for: weight))
        )
    }

    static func sans(
        size: CGFloat,
        weight: FaceWeight = .regular,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        font(
            names: canvaSansNames(for: weight) + fallbackSansNames(for: weight),
            size: size,
            relativeTo: textStyle,
            fallback: .system(size: size, weight: systemWeight(for: weight), design: .default)
        )
    }

    private static func font(
        names: [String],
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        fallback: Font
    ) -> Font {
        guard let name = names.first(where: { UIFont(name: $0, size: size) != nil }) else {
            return fallback
        }

        return .custom(name, size: size, relativeTo: textStyle)
    }

    private static func canvaDisplayNames(for weight: FaceWeight) -> [String] {
        switch weight {
        case .regular:
            return ["CanvaSansDisplay-Regular", "Canva Sans Display Regular", "CanvaSansDisplay", "Canva Sans Display"]
        case .medium:
            return ["CanvaSansDisplay-Medium", "Canva Sans Display Medium", "CanvaSansDisplay-Regular", "Canva Sans Display"]
        case .bold:
            return ["CanvaSansDisplay-Bold", "Canva Sans Display Bold", "CanvaSansDisplay-Medium", "Canva Sans Display"]
        }
    }

    private static func canvaSansNames(for weight: FaceWeight) -> [String] {
        switch weight {
        case .regular:
            return ["CanvaSans-Regular", "Canva Sans Regular", "CanvaSans", "Canva Sans"]
        case .medium:
            return ["CanvaSans-Medium", "Canva Sans Medium", "CanvaSans-Regular", "Canva Sans"]
        case .bold:
            return ["CanvaSans-Bold", "Canva Sans Bold", "CanvaSans-Medium", "Canva Sans"]
        }
    }

    private static func fallbackDisplayNames(for weight: FaceWeight) -> [String] {
        switch weight {
        case .regular: return ["AvenirNext-Regular", "Avenir Next"]
        case .medium: return ["AvenirNext-Medium", "AvenirNext-DemiBold"]
        case .bold: return ["AvenirNext-Bold", "AvenirNext-DemiBold"]
        }
    }

    private static func fallbackSansNames(for weight: FaceWeight) -> [String] {
        switch weight {
        case .regular: return ["AvenirNext-Regular", "Avenir Next"]
        case .medium: return ["AvenirNext-Medium", "AvenirNext-DemiBold"]
        case .bold: return ["AvenirNext-DemiBold", "AvenirNext-Bold"]
        }
    }

    private static func systemWeight(for weight: FaceWeight) -> Font.Weight {
        switch weight {
        case .regular: return .regular
        case .medium: return .medium
        case .bold: return .bold
        }
    }

    private static func defaultSize(for textStyle: Font.TextStyle) -> CGFloat {
        switch textStyle {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline: return 17
        case .body: return 17
        case .callout: return 16
        case .subheadline: return 15
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        @unknown default: return 17
        }
    }
}

extension View {
    @ViewBuilder
    func loginInputGlass(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(AppColor.inputSurface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .glassEffect(
                    .regular.tint(AppColor.inputSurfaceTint).interactive(),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(AppColor.groupBorder, lineWidth: 1)
                }
        } else {
            self
                .background(AppColor.inputSurface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(AppColor.groupBorder, lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    func loginGlassProminentButton() -> some View {
        modifier(LoginProminentButtonModifier())
    }
}

private struct LoginProminentButtonModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.plain)
                .foregroundStyle(foreground)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(background)
                }
                .glassEffect(
                    .regular.tint(glassTint).interactive(),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(stroke, lineWidth: 1)
                }
                .saturation(isEnabled ? 1 : 0.18)
                .opacity(isEnabled ? 1 : 0.64)
        } else {
            content
                .buttonStyle(.plain)
                .foregroundStyle(foreground)
                .background(
                    background,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(stroke, lineWidth: 1)
                }
                .saturation(isEnabled ? 1 : 0.18)
                .opacity(isEnabled ? 1 : 0.64)
        }
    }

    private var foreground: Color {
        isEnabled ? .white : AppColor.ink.opacity(0.48)
    }

    private var background: Color {
        isEnabled ? AppColor.lilac : AppColor.ink.opacity(0.12)
    }

    private var glassTint: Color {
        isEnabled ? AppColor.lilac.opacity(0.34) : AppColor.ink.opacity(0.08)
    }

    private var stroke: Color {
        isEnabled ? .white.opacity(0.22) : AppColor.ink.opacity(0.10)
    }
}
