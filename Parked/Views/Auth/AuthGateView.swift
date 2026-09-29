//
//  AuthGateView.swift
//  SnapLingo
//

import SwiftUI

struct AuthGateView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var didStartRestore = false

    var body: some View {
        Group {
            if authManager.isRestoringSession {
                loadingState
            } else if authManager.currentSession == nil {
                SignInView()
            } else {
                RootTabView()
            }
        }
        .task {
            guard !didStartRestore else { return }
            didStartRestore = true
            await authManager.restoreSession()
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("正在恢复你的账户...")
                .font(.headline)
            Text("词库、复习记录和个人档案会按当前用户自动加载。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}
