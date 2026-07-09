//
//  LogConsole.swift
//  Ortto iOS SDK Push Demo
//
//  Diagnostic log and configuration views for the Ortto iOS SDK demo app.
//

import SwiftUI

struct MatrixLogConsole: View {
    let entries: [LogEntry]

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if entries.isEmpty {
                            EmptyConsoleState()
                        } else {
                            ForEach(entries.indices, id: \.self) { index in
                                ConsoleLine(entry: entries[index])
                                    .id(index)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 18) + 22)
                }
                .onChange(of: entries.count) { _ in
                    if let last = entries.indices.last {
                        withAnimation(.easeOut(duration: 0.18)) {
                            scrollProxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(MatrixBackdrop().ignoresSafeArea())
        }
    }
}

struct ConsoleLine: View {
    let entry: LogEntry

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                ConsolePrompt(entry: entry, timestamp: Self.timestampFormatter.string(from: entry.date))
                messageText
            }

            VStack(alignment: .leading, spacing: 3) {
                ConsolePrompt(entry: entry, timestamp: Self.timestampFormatter.string(from: entry.date))
                messageText
                    .padding(.leading, 12)
            }
        }
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var messageText: some View {
        Text(entry.message)
            .font(.system(size: 12, design: .monospaced).weight(.medium))
            .foregroundStyle(lineColor)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var lineColor: Color {
        if entry.level == .error || entry.message.localizedCaseInsensitiveContains("error") {
            return Color(red: 1.00, green: 0.48, blue: 0.42)
        }
        if entry.level == .warning {
            return Color(red: 1.00, green: 0.78, blue: 0.30)
        }
        if entry.level == .debug {
            return MatrixColor.dim
        }
        if entry.message.localizedCaseInsensitiveContains("success") {
            return MatrixColor.primary
        }
        return MatrixColor.output
    }
}

struct ConsolePrompt: View {
    let entry: LogEntry
    let timestamp: String

    private var sourceColor: Color {
        switch entry.source {
        case .sdk:
            return MatrixColor.ortto
        case .demo:
            return MatrixColor.primary
        }
    }

    private var levelColor: Color {
        switch entry.level {
        case .info:
            return MatrixColor.primary
        case .debug:
            return MatrixColor.secondary
        case .warning:
            return Color(red: 1.00, green: 0.76, blue: 0.28)
        case .error:
            return Color(red: 1.00, green: 0.48, blue: 0.42)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(entry.source.rawValue)
                .foregroundStyle(sourceColor)
            Text("@")
                .foregroundStyle(MatrixColor.dim)
            Text(entry.source.promptHost)
                .foregroundStyle(MatrixColor.host)
            Text(" [\(timestamp)]")
                .foregroundStyle(MatrixColor.dim)
            Text(" % ")
                .foregroundStyle(MatrixColor.primary)
            if entry.level != .info {
                Text("\(entry.level.rawValue) ")
                    .foregroundStyle(levelColor)
            }
        }
        .font(.system(size: 12, design: .monospaced).weight(.semibold))
        .fixedSize()
    }
}

struct EmptyConsoleState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "terminal")
                .font(AppTypography.sans(.title2, weight: .bold))
                .foregroundStyle(MatrixColor.primary)
            Text("demo@push-demo % waiting for log events")
                .font(.system(size: 12, design: .monospaced).weight(.bold))
                .foregroundStyle(MatrixColor.primary)
            Text("ortto@ios-sdk % idle")
                .font(.system(size: 12, design: .monospaced).weight(.semibold))
                .foregroundStyle(MatrixColor.dim)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
    }
}

enum MatrixColor {
    static let primary = Color(red: 0.38, green: 1.00, blue: 0.58)
    static let ortto = Color(red: 0.56, green: 0.88, blue: 1.00)
    static let output = Color(red: 0.88, green: 0.94, blue: 0.90)
    static let host = Color(red: 0.73, green: 0.86, blue: 0.77)
    static let dim = Color(red: 0.47, green: 0.60, blue: 0.52)
    static let surface = Color(red: 0.01, green: 0.025, blue: 0.02)
    static let secondary = dim
}

struct MatrixBackdrop: View {
    var body: some View {
        MatrixColor.surface
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [
                        MatrixColor.primary.opacity(0.07),
                        MatrixColor.surface,
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 220)
            }
    }
}
