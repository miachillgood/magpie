//
//  SignInOptionsView.swift
//  SnapLingo
//
//  选登录方式：通过 Apple / 手机号 / 邮箱，或者先不登录（苹果规定不能强制登录）。
//

import AuthenticationServices
import SwiftUI

struct SignInOptionsView: View {
    var onApple: (Result<ASAuthorization, Error>) -> Void
    var onPhone: () -> Void
    var onEmail: () -> Void
    var onSkip: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            content(compact: proxy.size.height < 700)
        }
    }

    private func content(compact: Bool) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    MagpieLogo(size: compact ? 60 : 84)
                        .overlay(alignment: .topTrailing) {
                            HStack(alignment: .top, spacing: 0) {
                                SparkleLines()
                                    .stroke(Theme.sparkle, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                    .frame(width: 26, height: 26)
                                Text(verbatim: "Hi!")
                                    .font(.handwriting(28))
                                    .foregroundStyle(Theme.homeInk)
                                    .rotationEffect(.degrees(-8))
                                    .offset(y: 8)
                            }
                            .offset(x: 62, y: -12)
                            .accessibilityHidden(true)
                        }
                        .padding(.top, compact ? 12 : 28)

                    Text("登录后，单词不会丢")
                        .font(.system(size: compact ? 24 : 28, weight: .heavy))
                        .foregroundStyle(Theme.homeInk)
                        .multilineTextAlignment(.center)
                        .padding(.top, compact ? 14 : 22)
                        .accessibilityAddTraits(.isHeader)
                    Text("自动备份到云端，换手机登录就能找回。不登录也能用全部功能。")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.homeMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)

                    VStack(spacing: 0) {
                        BenefitRow(symbol: "checkmark.icloud", title: "自动备份", detail: compact ? nil : "单词、照片和复习记录都会存一份", dense: compact)
                        Divider().padding(.leading, 46)
                        BenefitRow(symbol: "ipad.and.iphone", title: "多台设备同步", detail: compact ? nil : "iPhone 和 iPad 登录同一个账号，进度一样", dense: compact)
                        Divider().padding(.leading, 46)
                        BenefitRow(symbol: "trash", title: "随时可以删除", detail: compact ? nil : "在“我的”里能删除账号和全部云端数据", dense: compact)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(Theme.sheet, in: .rect(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                    .padding(.top, compact ? 16 : 24)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)

            VStack(spacing: 10) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    onApple(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 52)
                .clipShape(.capsule)

                MethodButton(title: "用手机号登录", symbol: "iphone", action: onPhone)
                MethodButton(title: "用邮箱登录", symbol: "envelope", action: onEmail)

                Button("先不登录", action: onSkip)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.homeMuted)
                    .frame(height: 40)
                    .padding(.top, 2)
                Text("不登录的话，数据只存在这台手机上")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.homeMuted)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }
}

private struct BenefitRow: View {
    var symbol: String
    var title: LocalizedStringKey
    var detail: LocalizedStringKey?
    var dense = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.homeInk)
                .frame(width: dense ? 30 : 34, height: dense ? 30 : 34)
                .background(Pastel.peach, in: .rect(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                if let detail {
                    Text(detail)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.homeMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(Theme.homeInk)
            Spacer(minLength: 0)
        }
        .padding(.vertical, dense ? 6 : 11)
        .accessibilityElement(children: .combine)
    }
}

/// 白色胶囊按钮：手机号 / 邮箱
private struct MethodButton: View {
    var title: LocalizedStringKey
    var symbol: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.homeInk)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.sheet, in: .capsule)
                .overlay(Capsule().strokeBorder(Theme.homeInk.opacity(0.1)))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        }
        .buttonStyle(.pressable)
    }
}
