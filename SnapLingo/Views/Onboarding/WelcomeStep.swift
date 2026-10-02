//
//  WelcomeStep.swift
//  SnapLingo
//
//  第一次打开：奶油色底，手写字标「Magpie」和一句口号，下面是举着相机的喜鹊。
//  插画是透明底的 PNG（WelcomeWordmark / WelcomeMagpie），深色模式下也保持浅色底，黑色的喜鹊才看得清。
//  出场顺序：字标落下 → 口号淡入 → 喜鹊弹出来，之后轻轻上下浮动。
//

import SwiftUI

struct WelcomeStep: View {
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var floating = false

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 700
            VStack(spacing: 0) {
                Spacer(minLength: compact ? 12 : 24)

                Image("WelcomeWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: compact ? 72 : 92)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -16)
                    .animation(motion(.spring(response: 0.6, dampingFraction: 0.7), delay: 0.05), value: appeared)
                    .accessibilityLabel(Text(verbatim: "Magpie"))
                    .accessibilityAddTraits(.isHeader)

                Text("Real English\nfor everyday life.", comment: "Welcome tagline under the Magpie wordmark; keep the line break")
                    .font(.system(size: compact ? 19 : 22, weight: .medium))
                    .foregroundStyle(Theme.homeInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, compact ? 10 : 16)
                    .opacity(appeared ? 1 : 0)
                    .animation(motion(.easeOut(duration: 0.5), delay: 0.3), value: appeared)

                Spacer(minLength: 16)

                Image("WelcomeMagpie")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: min(proxy.size.width * 0.82, 340))
                    .offset(y: floating ? -6 : 0)
                    .scaleEffect(appeared ? 1 : 0.6, anchor: .bottom)
                    .opacity(appeared ? 1 : 0)
                    .animation(motion(.spring(response: 0.7, dampingFraction: 0.6), delay: 0.45), value: appeared)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: floating)
                    .accessibilityHidden(true)

                Spacer(minLength: 16)

                PrimaryButton(title: "开始", trailingSymbol: "arrow.right", action: onContinue)
                Text("不用注册", comment: "Small note under the welcome page's Get started button")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.homeMuted)
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .background {
            Theme.cream.ignoresSafeArea()
        }
        // 插画是黑色线条，固定浅色底和浅色文字配色
        .environment(\.colorScheme, .light)
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                Task {
                    try? await Task.sleep(for: .milliseconds(80))
                    appeared = true
                    try? await Task.sleep(for: .milliseconds(1300))
                    floating = true
                }
            }
        }
    }

    private func motion(_ animation: Animation, delay: Double) -> Animation? {
        reduceMotion ? nil : animation.delay(delay)
    }
}
