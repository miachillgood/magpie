//
//  CameraPermissionView.swift
//  SnapLingo
//

import SwiftUI

/// 第一次打开相机前先说明为什么要用相机，再弹系统的权限框；被拒绝过就引导去设置里打开
struct CameraPermissionView: View {
    enum Mode {
        /// 还没问过
        case ask
        /// 拒绝过，系统不会再弹框
        case denied
    }

    var mode: Mode
    var onAllow: () -> Void
    var onPickPhoto: () -> Void
    var onLater: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            // 和水平测试结果页一样，手写标题所有语言都用英文
            Text(verbatim: "Let's get\ncamera ready!")
                .font(.handwriting(52))
                .foregroundStyle(Theme.homeInk)
                .multilineTextAlignment(.center)
                .lineSpacing(-6)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .modifier(Entrance(appeared: appeared, delay: 0, reduceMotion: reduceMotion))

            Text(mode == .ask
                 ? "Magpie 需要使用相机，帮你在生活里发现英语。"
                 : "相机权限被关掉了。去设置里打开，就能拍下身边的英语。")
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.homeInk.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.md)
                .padding(.horizontal, Spacing.md)
                .modifier(Entrance(appeared: appeared, delay: 0.1, reduceMotion: reduceMotion))

            Spacer(minLength: 16)

            Image("CameraMagpie")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 290, maxHeight: 260)
                .rotationEffect(.degrees(appeared ? 0 : -6), anchor: .bottom)
                .scaleEffect(appeared ? 1 : 0.85, anchor: .bottom)
                .opacity(appeared ? 1 : 0)
                .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.65).delay(0.2), value: appeared)
                .accessibilityHidden(true)

            Spacer(minLength: 24)

            VStack(spacing: Spacing.md) {
                if mode == .ask {
                    PrimaryButton(title: "允许使用相机", action: onAllow)
                } else {
                    PrimaryButton(title: "去设置打开", action: openSettings)
                    Button("从相册选择", action: onPickPhoto)
                        .font(.headline)
                        .foregroundStyle(Theme.homeInk)
                }
                Button("以后再说", action: onLater)
                    .font(.headline)
                    .foregroundStyle(Theme.homeInk.opacity(0.55))
            }
            .modifier(Entrance(appeared: appeared, delay: 0.3, reduceMotion: reduceMotion))
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Self.background.ignoresSafeArea())
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                Task {
                    try? await Task.sleep(for: .milliseconds(80))
                    appeared = true
                }
            }
        }
    }

    /// 效果图里的淡紫色
    static let background = Color(light: UIColor(hex: 0xE9E6F7), dark: UIColor(hex: 0x24213A))

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
