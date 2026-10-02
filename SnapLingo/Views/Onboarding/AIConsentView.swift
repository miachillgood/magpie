//
//  AIConsentView.swift
//  SnapLingo
//
//  发文字给 AI 之前先说清楚：发什么、不发什么、发给谁，由用户点同意（审核规则 5.1.2(i)）。
//  不放在引导里：第一次拍完照、真要用 AI 时从底部弹出半屏（见 ScanFlowView）；
//  「我的」里重新打开、单词页里补释义时也用同一个弹窗。
//

import SwiftUI
import SwiftData

struct AIConsentView: View {
    var onAgree: () -> Void
    var onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("让 AI 帮你挑词、写释义")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.homeInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Magpie 用 Anthropic 的 Claude 从照片文字里挑出适合你的词，再用你的母语写释义和例句。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                item(symbol: "arrow.up", color: Pastel.sky, title: "会发送",
                     detail: "照片里识别出的英文文字、挑出的单词，以及你的英语水平和母语")
                item(symbol: "lock", color: Pastel.mint, title: "不会发送",
                     detail: "照片本身、昵称、头像和 Apple 账号")
                item(symbol: "exclamationmark", color: Pastel.butter, title: "请留意",
                     detail: "拍到的文字里如果有姓名、地址这类个人信息，也会一起发送")
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: .rect(cornerRadius: Radius.card - 4, style: .continuous))

            Link(destination: AIConsent.privacyPolicyURL) {
                Label("Anthropic 隐私政策", systemImage: "arrow.up.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.ink)
            }

            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "同意", symbol: "checkmark", action: onAgree)
                Button("先不用", action: onDecline)
                    .font(.headline)
                    .foregroundStyle(Theme.ink.opacity(0.6))
                    .frame(maxWidth: .infinity)
                Text("不同意也可以拍照、手动选词和复习，只是没有自动挑词和释义。随时可以在“我的”里更改。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg + 4)
        .padding(.bottom, Spacing.sm)
    }

    private func item(symbol: String, color: Color, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 26, height: 26)
                .background(color, in: .rect(cornerRadius: 8, style: .continuous))
            (Text(title).fontWeight(.heavy).foregroundStyle(Theme.ink) + Text(verbatim: "  ") + Text(detail).foregroundStyle(.secondary))
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 底部半屏弹窗：高度跟着内容走，必须选一个才能关掉
struct AIConsentSheet: View {
    /// 选完之后（同意或先不用）
    var onDecided: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var height: CGFloat = 520

    var body: some View {
        ScrollView {
            AIConsentView {
                AIConsent.grant(context: context)
                finish()
            } onDecline: {
                AIConsent.decline()
                finish()
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .background(OnboardingBackground())
        .presentationDetents([.height(height)])
        .presentationCornerRadius(32)
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
    }

    private func finish() {
        dismiss()
        onDecided()
    }
}
