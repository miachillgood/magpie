//
//  WelcomeStep.swift
//  SnapLingo
//
//  第一次打开：米白底，蜡笔手写字标「Magpie」和一句手写口号，下面是叼着信飞过街道的喜鹊。
//  插画是透明底的 PNG（WelcomeWordmark / WelcomeMagpie），深色模式下也保持浅色底，黑色线条才看得清。
//  出场顺序：字标落下 → 口号淡入 → 街景插画浮现，之后喜鹊轻轻上下浮动。
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
                Spacer(minLength: compact ? 8 : 24)

                Image("WelcomeWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(proxy.size.width * 0.64, 280))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -16)
                    .animation(motion(.spring(response: 0.6, dampingFraction: 0.7), delay: 0.05), value: appeared)
                    .accessibilityLabel(Text(verbatim: "Magpie"))
                    .accessibilityAddTraits(.isHeader)

                // 手写口号原图（所有语言都一样），读屏读当地语言
                Image("WelcomeTagline")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(proxy.size.width * 0.44, 190))
                    .accessibilityLabel(Text("Pick up words\nas you go.", comment: "Handwritten welcome tagline under the Magpie wordmark; keep the line break"))
                    .padding(.top, compact ? 8 : 14)
                    .opacity(appeared ? 1 : 0)
                    .animation(motion(.easeOut(duration: 0.5), delay: 0.3), value: appeared)

                Spacer(minLength: 8)

                // 街景插画左右贴边，不受页面内边距限制
                Image("WelcomeMagpie")
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width)
                    .frame(maxHeight: proxy.size.height * (compact ? 0.48 : 0.56))
                    .offset(y: floating ? -4 : 0)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(motion(.easeOut(duration: 0.7), delay: 0.45), value: appeared)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: floating)
                    .padding(.horizontal, -24)
                    .accessibilityHidden(true)

                Spacer(minLength: 12)

                // 「Get started →」原图比 Continue 扁长，矮一点，看起来分量差不多
                SketchImageButton(image: "GetStartedButton", label: "开始", height: 70, action: onContinue)

                Text("不用注册", comment: "Small note under the welcome page's Get started button")
                    .font(.custom("ChalkboardSE-Light", size: 15))
                    .foregroundStyle(Theme.homeMuted)
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .background {
            Theme.sketchPaper.ignoresSafeArea()
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
