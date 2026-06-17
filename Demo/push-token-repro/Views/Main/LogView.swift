//
//  LogView.swift
//  Ortto iOS SDK Push Demo
//
//  The Log tab: a terminal-style console of SDK and demo log entries.
//

import OrttoSDKCore
import SwiftUI

struct LogView: View {
    @ObservedObject var viewModel: PushViewModel

    var body: some View {
        MatrixLogConsole(entries: viewModel.logEntries)
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(MatrixColor.surface, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                // Ortto SDK: record this screen view.
                Ortto.shared.screen(AppTab.diagnostics.screenName)
                viewModel.logScreenView(.diagnostics)
            }
    }
}
