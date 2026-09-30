//
//  CodeEntryView.swift
//  SnapLingo
//
//  输入 6 位验证码。手机和邮箱共用；iPhone 会从短信或邮件里自动填入，填满 6 位就提交。
//

import SwiftUI

struct CodeEntryView: View {
    enum Channel: Equatable {
        case sms
        case email
    }

    var channel: Channel
    /// 打码后的号码或邮箱
    var destination: String
    var onBack: () -> Void
    var verify: (_ code: String) async throws -> Void
    var resend: () async throws -> Void

    @State private var code = ""
    @State private var verifying = false
    @State private var error: String?
    @State private var secondsLeft = CodeEntryView.resendDelay
    @State private var resendRound = 0
    @State private var shakes = 0
    @FocusState private var focused: Bool

    static let resendDelay = 60

    var body: some View {
        AccountScaffold(title: "输入验证码", subtitle: Text("已发送到 \(destination)"), onBack: onBack) {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    // 真正接收输入的是这个看不见的输入框，下面 6 个格子只负责显示
                    TextField("", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($focused)
                        .foregroundStyle(.clear)
                        .tint(.clear)
                        .accessibilityLabel("验证码")
                    boxes
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .contentShape(.rect)
                .onTapGesture { focused = true }
                .modifier(Shake(amount: shakes))
                .animation(.default, value: shakes)

                HStack(alignment: .top, spacing: 8) {
                    if verifying {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "sparkles").font(.system(size: 14, weight: .semibold))
                    }
                    Text(error ?? hint)
                        .font(.system(size: 13, weight: error == nil ? .regular : .semibold))
                        .foregroundStyle(error == nil ? Theme.homeInk : Theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.sheet.opacity(0.7), in: .rect(cornerRadius: 16, style: .continuous))

                HStack {
                    if secondsLeft > 0 {
                        Text("\(secondsLeft) 秒后可以重新发送")
                            .foregroundStyle(Theme.homeMuted)
                            .contentTransition(.numericText())
                    } else {
                        Button("重新发送") { resendCode() }
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.homeInk)
                    }
                    Spacer()
                    Button(channel == .sms ? "换个号码" : "换个邮箱", action: onBack)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.homeInk)
                }
                .font(.system(size: 14))
            }
        }
        .onAppear { focused = true }
        .onChange(of: code) { _, newValue in
            let cleaned = AccountInput.sanitizedCode(newValue)
            if cleaned != newValue {
                code = cleaned
                return
            }
            error = nil
            if cleaned.count == AccountInput.codeLength { submit(cleaned) }
        }
        .task(id: resendRound) {
            secondsLeft = CodeEntryView.resendDelay
            while secondsLeft > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                withAnimation { secondsLeft -= 1 }
            }
        }
        .sensoryFeedback(.error, trigger: shakes)
    }

    private var hint: String {
        switch channel {
        case .sms: String(localized: "iPhone 会从短信里自动填入验证码，填满 6 位就登录。")
        case .email: String(localized: "iPhone 会从邮件里自动填入验证码，填满 6 位就登录。")
        }
    }

    private var boxes: some View {
        let digits = Array(code)
        return HStack(spacing: 8) {
            ForEach(0..<AccountInput.codeLength, id: \.self) { index in
                let isActive = focused && index == min(digits.count, AccountInput.codeLength - 1) && digits.count < AccountInput.codeLength
                ZStack {
                    if index < digits.count {
                        Text(String(digits[index]))
                            .font(.brand(28))
                            .foregroundStyle(Theme.homeInk)
                    } else if isActive {
                        Capsule().fill(Theme.homeInk).frame(width: 2, height: 26)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Theme.sheet, in: .rect(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isActive ? Theme.homeInk : Theme.homeInk.opacity(0.1), lineWidth: isActive ? 2.5 : 1)
                )
            }
        }
    }

    private func submit(_ value: String) {
        guard !verifying else { return }
        verifying = true
        Task {
            defer { verifying = false }
            do {
                try await verify(value)
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? AccountError.wrongCode.localizedDescription
                code = ""
                shakes += 1
            }
        }
    }

    private func resendCode() {
        Task {
            do {
                try await resend()
                error = nil
                resendRound += 1
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? AccountError.sendFailed.localizedDescription
            }
        }
    }
}

/// 输错验证码时左右晃一下
private struct Shake: GeometryEffect {
    var amount: Int
    var animatableData: CGFloat

    init(amount: Int) {
        self.amount = amount
        self.animatableData = CGFloat(amount)
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(animatableData * .pi * 4), y: 0))
    }
}
