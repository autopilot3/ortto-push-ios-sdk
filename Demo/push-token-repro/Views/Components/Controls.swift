//
//  Controls.swift
//  Ortto iOS SDK Push Demo
//
//  Shared controls used across the demo screens.
//

import SwiftUI

struct SDKToastView: View {
    let toast: SDKToast

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(toast.tone.tint.opacity(0.16))
                Image(systemName: toast.tone == .working ? "clock.fill" : toast.tone.symbol)
                    .font(AppTypography.sans(.subheadline, weight: .bold))
                    .foregroundStyle(toast.tone.tint)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(toast.title)
                    .font(AppTypography.sans(.subheadline, weight: .bold))
                    .foregroundStyle(AppColor.ink)
                Text(toast.detail)
                    .font(AppTypography.sans(.caption, weight: .medium))
                    .foregroundStyle(AppColor.ink.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: 520, alignment: .leading)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(toast.tone.tint.opacity(0.20), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .compositingGroup()
        .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 10)
    }
}

struct CopyableValue: View {
    let value: String
    var displayValue: String?
    var isMonospaced = false
    let copy: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Text(displayValue ?? value)
                .font(valueFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .multilineTextAlignment(.trailing)

            Button(action: copy) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.lilac)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Copy")
        }
    }

    private var valueFont: Font {
        isMonospaced ? .system(.footnote, design: .monospaced).weight(.semibold) : AppTypography.sans(.body)
    }
}

struct ModalRowButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(AppTypography.sans(.body, weight: .medium))
                Spacer()
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColor.lilac)
            }
        }
    }
}

struct DeliveryActionButton: View {
    let title: String
    let detail: String
    let tint: Color
    var isLoading = false
    var status: SDKActionStatus?
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppTypography.sans(.body, weight: .bold))
                        .foregroundStyle(isEnabled ? tint : .secondary)
                    Text(detail)
                        .font(AppTypography.sans(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let status {
                        HStack(spacing: 5) {
                            Image(systemName: status.tone.symbol)
                                .font(.system(size: 10, weight: .bold))
                            Text(status.text)
                                .font(AppTypography.sans(.caption2, weight: .bold))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(status.tone.tint)
                        .padding(.top, 2)
                    }
                }

                Spacer(minLength: 12)

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(tint)
                } else {
                    Image(systemName: "arrow.up.forward.circle.fill")
                        .font(AppTypography.sans(.title3, weight: .bold))
                        .foregroundStyle(isEnabled ? tint : .secondary)
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .listRowBackground(tint.opacity(isEnabled ? 0.12 : 0.05))
    }
}
