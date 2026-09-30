//
//  LoginFlowView.swift
//  SnapLingo
//
//  引导里的登录：选方式 → 手机号 / 邮箱 → 验证码。登录成功或「先不登录」都往下走。
//

import AuthenticationServices
import SwiftUI

struct LoginFlowView: View {
    var actions: AccountActions
    var onApple: (Result<ASAuthorization, Error>) -> Void
    /// 登录成功或选择先不登录
    var onDone: () -> Void

    private enum Page: Equatable {
        case options
        case phone
        case email
        case code(channel: CodeEntryView.Channel, address: String, masked: String)
    }

    @State private var page: Page = {
        #if DEBUG
        switch OnboardingDebug.value(after: "-loginPage") {
        case "phone": .phone
        case "email": .email
        case "code": .code(channel: .sms, address: "+64212345678", masked: "+64 21 •••• 678")
        default: .options
        }
        #else
        .options
        #endif
    }()

    var body: some View {
        ZStack {
            switch page {
            case .options:
                SignInOptionsView(
                    onApple: onApple,
                    onPhone: { go(.phone) },
                    onEmail: { go(.email) },
                    onSkip: onDone
                )
                .transition(.move(edge: .leading).combined(with: .opacity))
            case .phone:
                PhoneEntryView(onBack: { go(.options) }) { phone, masked in
                    try await actions.sendPhoneCode(phone)
                    go(.code(channel: .sms, address: phone, masked: masked))
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            case .email:
                EmailEntryView(onBack: { go(.options) }) { email, masked in
                    try await actions.sendEmailCode(email)
                    go(.code(channel: .email, address: email, masked: masked))
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            case .code(let channel, let address, let masked):
                CodeEntryView(
                    channel: channel,
                    destination: masked,
                    onBack: { go(channel == .sms ? .phone : .email) },
                    verify: { code in
                        switch channel {
                        case .sms: try await actions.verifyPhoneCode(address, code)
                        case .email: try await actions.verifyEmailCode(address, code)
                        }
                        onDone()
                    },
                    resend: {
                        switch channel {
                        case .sms: try await actions.sendPhoneCode(address)
                        case .email: try await actions.sendEmailCode(address)
                        }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }

    private func go(_ next: Page) {
        withAnimation(.smooth) { page = next }
    }
}
