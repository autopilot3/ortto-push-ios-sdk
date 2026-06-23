//
//  MainTabView.swift
//  Ortto iOS SDK Push Demo
//
//  The signed-in experience: a tab bar hosting the three demo screens
//  (Home, Delivery, Log) plus the Technical Details sheet.
//

import SwiftUI

struct MainTabView: View {
    @Bindable var viewModel: PushViewModel

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            NavigationStack {
                HomeView(viewModel: viewModel)
                    .navigationTitle("Push registration")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                viewModel.logout()
                            } label: {
                                Image(systemName: "person.crop.circle.badge.xmark")
                            }
                            .accessibilityLabel("Sign out")
                            .disabled(viewModel.isLoggingOut)
                        }
                    }
                    .sheet(isPresented: $viewModel.isShowingTechnicalDetails) {
                        technicalDetailsSheet
                    }
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(AppTab.home)

            NavigationStack {
                DeliveryView(viewModel: viewModel)
                    .navigationTitle("Delivery")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem { Label("Delivery", systemImage: "bell.badge") }
            .tag(AppTab.delivery)

            NavigationStack {
                LogView(viewModel: viewModel)
            }
            .tabItem { Label("Log", systemImage: "terminal.fill") }
            .tag(AppTab.diagnostics)
        }
        .tint(viewModel.selectedTab == .diagnostics ? MatrixColor.primary : AppColor.lilac)
        .toolbarBackground(viewModel.selectedTab == .diagnostics ? MatrixColor.surface : Color.clear, for: .tabBar)
        .toolbarColorScheme(viewModel.selectedTab == .diagnostics ? ColorScheme.dark : nil, for: .tabBar)
        .preferredColorScheme(viewModel.selectedTab == .diagnostics ? .dark : .light)
    }

    private var technicalDetailsSheet: some View {
        NavigationStack {
            TechnicalDetailsView(viewModel: viewModel)
                .navigationTitle("Technical Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            viewModel.isShowingTechnicalDetails = false
                        }
                    }
                }
        }
    }
}
