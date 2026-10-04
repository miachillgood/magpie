//
//  IntroStep.swift
//  SnapLingo
//
//  欢迎页之后的介绍页：和欢迎页同一张米白纸底、同一种蜡笔画风。
//  上面是手写标题「Collect English as you go.」（IntroTitle，自带黄色光芒），
//  中间是一整张街景插画（IntroScene：喜鹊叼走 Coffee 卡片、单词卡满天飞、少年追着跑），
//  下面一句手写的话（设计图，「Snap it.」下面带黄线），再是继续按钮。
//  插画都是透明底 PNG，深色模式下也保持浅色底，黑色线条才看得清。
//  出场顺序：标题从左往右写出来 → 插画浮现，之后轻轻上下浮动 → 底部的话、黄线划开 → 按钮。
//

import SwiftUI

struct IntroStep: View {
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var floating = false

    private static let footerDelay = 1.1

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let compact = proxy.size.height < 700
            VStack(spacing: 0) {
                title
                    .frame(width: min(width * 0.8, 360))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, width * 0.06)
                    .padding(.top, compact ? 4 : 16)

                // 插画左右贴边；高度不够时整张缩小。顶上的路牌和标题稍微叠一点，跟设计稿一样
                Image("IntroScene")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: width, maxHeight: .infinity)
                    .padding(.top, -width * 0.05)
                    .offset(y: floating ? -4 : 0)
                    .scaleEffect(appeared ? 1 : 0.96, anchor: .bottom)
                    .opacity(appeared ? 1 : 0)
                    .animation(motion(.easeOut(duration: 0.7), delay: 0.45), value: appeared)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: floating)
                    .accessibilityHidden(true)

                footer(width: width, compact: compact)
                    .padding(.top, compact ? 8 : 14)

                ContinueSketchButton(action: onContinue)
                    .padding(.top, compact ? 16 : 24)
                    .padding(.bottom, 8)
                    .modifier(Entrance(appeared: appeared, delay: Self.footerDelay + 0.15, reduceMotion: reduceMotion))
            }
            .frame(width: width, height: proxy.size.height, alignment: .top)
        }
        .background(Theme.sketchPaper.ignoresSafeArea())
        // 插画是固定配色，深色模式下也保持浅色底
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

    /// 手写标题图，所有语言都用英文；出现时像被写出来一样从左往右露出
    private var title: some View {
        Image("IntroTitle")
            .resizable()
            .scaledToFit()
            .mask(alignment: .leading) {
                Rectangle().scaleEffect(x: appeared ? 1 : 0.001, anchor: .leading)
            }
            .animation(motion(.easeOut(duration: 0.8), delay: 0.1), value: appeared)
            .accessibilityLabel(Text(verbatim: "Collect English as you go."))
            .accessibilityAddTraits(.isHeader)
    }

    /// 手写的「Spot something you don't know? Snap it.」设计图（黄线也画在图上），和标题一样所有语言都用英文；
    /// 出现时像被写出来一样从左往右露出
    private func footer(width: CGFloat, compact: Bool) -> some View {
        Image("IntroCaption")
            .resizable()
            .scaledToFit()
            .frame(width: min(width * (compact ? 0.74 : 0.8), 330))
            .mask(alignment: .leading) {
                Rectangle().scaleEffect(x: appeared ? 1 : 0.001, anchor: .leading)
            }
            .animation(motion(.easeOut(duration: 0.8), delay: Self.footerDelay), value: appeared)
            .accessibilityLabel(Text(verbatim: "Spot something you don't know? Snap it."))
    }

    private func motion(_ animation: Animation, delay: Double) -> Animation? {
        reduceMotion ? nil : animation.delay(delay)
    }
}
