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
            // MARK: - 扫描 Tab
            NavigationStack(path: $coordinator.scanPath) {
                CameraView()
                    .navigationTitle("扫一扫")
            }
            .tabItem {
                Label("扫描", systemImage: "camera.viewfinder")
            }
            .tag(AppTab.scan)

            // MARK: - 词库 Tab
            NavigationStack(path: $coordinator.libraryPath) {
                LibraryView()
            }
            .tabItem {
                Label("词库", systemImage: "books.vertical")
            }
            .tag(AppTab.library)

            // MARK: - 复习 Tab
            ReviewView()
                .tabItem {
                    Label("复习", systemImage: "brain.head.profile")
                }
                .tag(AppTab.review)
        }
    }
}

#Preview {
    RootTabView()
        .environment(AppCoordinator())
        .modelContainer(for: [VocabWord.self, ReviewSession.self, AppSettings.self],
                        inMemory: true)
}
