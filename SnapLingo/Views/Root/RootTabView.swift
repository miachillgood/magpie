//
//  RootTabView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(AppCoordinator.self) private var coordinator
    var body: some View {
        @Bindable var coordinator = coordinator

        TabView(selection: $coordinator.selectedTab) {
            // MARK: - 首页 Tab
            HomeView()
                .tabItem { Label("首页", systemImage: "house") }
                .tag(AppTab.home)

            // MARK: - 词库 Tab
            NavigationStack(path: $coordinator.libraryPath) {
                LibraryView()
            }
            .tabItem { Label("词库", systemImage: "books.vertical") }
            .tag(AppTab.library)

            // MARK: - 复习 Tab
            ReviewView()
                .tabItem { Label("复习", systemImage: "brain.head.profile") }
                .tag(AppTab.review)

            // MARK: - 我的 Tab
            ProfileView()
                .tabItem { Label("我的", systemImage: "person.circle") }
                .tag(AppTab.profile)
        }
        // 扫描流：全局 fullScreenCover，从任意位置触发
        .fullScreenCover(isPresented: $coordinator.showingScan) {
            NavigationStack(path: $coordinator.scanPath) {
                CameraView()
                    .navigationTitle("扫一扫")
            }
            .environment(coordinator)
        }
    }
}

#Preview {
    RootTabView()
        .environment(AppCoordinator())
        .modelContainer(for: [VocabWord.self, ReviewSession.self, AppSettings.self],
                        inMemory: true)
}
