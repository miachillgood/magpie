//
//  SignInView.swift
//  SnapLingo
//

import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 18) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
                    .frame(width: 96, height: 96)
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor, Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 28)
                    )

                VStack(spacing: 8) {
                    Text("登录后开始学习")
                        .font(.title2.bold())

                    Text("使用 Apple 登录后，SnapLingo 会把你的个人档案、词库、复习记录和学习进度绑定到当前账号。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }

            VStack(spacing: 14) {
                SignInWithAppleButton(.signIn) { request in
                    authManager.beginAuthentication()
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    authManager.handleAppleSignIn(result: result, context: modelContext)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .disabled(authManager.isAuthenticating)

                Text("不需要额外记账号密码，直接复用 Apple 的身份体系。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("当前版本需要先登录后再进入应用，这样词库和记录才能稳定绑定到你的账号。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            if let errorMessage = authManager.lastErrorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .padding(.vertical, 24)
        .background(Color(.systemGroupedBackground))
    }
}
