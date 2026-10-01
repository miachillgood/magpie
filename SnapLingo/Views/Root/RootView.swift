//
//  RootView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

/// 首次启动进入引导，之后进入主界面（不需要登录）
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \UserSettings.createdAt) private var settingsRows: [UserSettings]

    var body: some View {
        Group {
            if let settings = settingsRows.first {
                if settings.onboardingCompleted {
                    RootTabView()
                        .transition(.opacity)
                        #if DEBUG
                        .modifier(LevelResultPreview())
                        #endif
                } else {
                    OnboardingView(settings: settings)
                        .transition(.opacity)
                }
            } else {
                Theme.pageBackground.ignoresSafeArea()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: settingsRows.first?.onboardingCompleted)
        .task {
            _ = UserSettings.current(in: context)
        }
    }
}
