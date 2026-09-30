//
//  AccountComponents.swift
//  SnapLingo
//
//  登录各页共用的部件：返回按钮、页面骨架、输入框卡片、说明行。
//

import SwiftUI

/// 白色圆形返回按钮
struct CircleBackButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.homeInk)
                .frame(width: 42, height: 42)
                .background(Theme.sheet, in: .circle)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("返回")
    }
}

/// 登录各页的骨架：返回按钮、大标题、一句说明，下面放内容
struct AccountScaffold<Content: View>: View {
    var title: LocalizedStringKey
    var subtitle: Text
    var onBack: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CircleBackButton(action: onBack)
                Text(title)
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(Theme.homeInk)
                    .padding(.top, 22)
                    .accessibilityAddTraits(.isHeader)
                subtitle
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.homeMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                content
                    .padding(.top, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }
}

/// 白卡片里一个带标签的输入框（边框加粗表示正在输入）
struct AccountFieldCard<Field: View>: View {
    var label: LocalizedStringKey
    @ViewBuilder var field: Field

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.homeMuted)
            HStack(spacing: 8) { field }
                .padding(.horizontal, 8)
                .frame(height: 56)
                .background(Theme.mist, in: .rect(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.homeInk, lineWidth: 2))
        }
        .padding(16)
        .background(Theme.sheet, in: .rect(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}

/// 输入框下面的小字说明 / 错误提示
struct AccountNote: View {
    var text: String
    var isError = false

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: isError ? .semibold : .regular))
            .foregroundStyle(isError ? Theme.danger : Theme.homeMuted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
    }
}

/// 黑色主按钮：发送中显示转圈，不能点时变淡
struct AccountPrimaryButton: View {
    var title: LocalizedStringKey
    var enabled: Bool
    var busy: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if busy {
                    ProgressView().tint(Theme.cream)
                } else {
                    Text(title)
                    Image(systemName: "arrow.right")
                }
            }
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Theme.cream)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Theme.homeInk, in: .capsule)
            .opacity(enabled || busy ? 1 : 0.35)
        }
        .buttonStyle(.pressable)
        .disabled(!enabled || busy)
    }
}
