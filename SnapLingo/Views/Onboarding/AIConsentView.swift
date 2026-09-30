//
//  AIConsentView.swift
//  SnapLingo
//
//  发文字给 AI 之前先说清楚：发什么、不发什么、发给谁，由用户点同意。
//  引导页里是其中一步；老用户第一次打开、或在「我的」里重新打开时用弹窗。
//

import SwiftUI
import SwiftData

struct AIConsentView: View {
    var agreeTitle: LocalizedStringKey = "同意并继续"
    var onAgree: () -> Void
    var onDecline: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("让 AI 帮你挑词、写释义")
                            .font(.display)
                        Text("Magpie 用 Anthropic 的 Claude 从照片文字里挑出适合你的词，再用你的母语写释义和例句。")
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: Spacing.sm) {
                        item(symbol: "arrow.up", color: Pastel.sky, title: "会发送",
                             detail: "照片里识别出的英文文字、挑出的单词，以及你的英语水平和母语")
                        item(symbol: "lock", color: Pastel.mint, title: "不会发送",
                             detail: "照片本身、昵称、头像和 Apple 账号")
                        item(symbol: "exclamationmark", color: Pastel.butter, title: "请留意",
                             detail: "拍到的文字里如果有姓名、地址这类个人信息，也会一起发送")
                    }
                }
                .padding(.top, Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: Spacing.sm) {
                // 放在按钮上面，不管说明多长都看得到
                Link(destination: AIConsent.privacyPolicyURL) {
                    Label("Anthropic 隐私政策", systemImage: "arrow.up.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                }
                PrimaryButton(title: agreeTitle, symbol: "checkmark", action: onAgree)
                Button("先不用", action: onDecline)
                    .font(.headline)
                    .foregroundStyle(Theme.ink.opacity(0.6))
                Text("不同意也可以拍照、手动选词和复习，只是没有自动挑词和释义。随时可以在“我的”里更改。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.lg)
    }

    private func item(symbol: String, color: Color, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 34, height: 34)
                .background(color, in: .rect(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.heavy))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(Theme.card, in: .rect(cornerRadius: Radius.card - 4, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// 弹窗版本：必须选一个才能关掉
struct AIConsentSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            OnboardingBackground()
            AIConsentView(agreeTitle: "同意") {
                AIConsent.grant(context: context)
                dismiss()
            } onDecline: {
                AIConsent.decline()
                dismiss()
            }
        }
        .interactiveDismissDisabled()
    }
}
