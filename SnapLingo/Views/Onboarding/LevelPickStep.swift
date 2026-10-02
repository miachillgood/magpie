//
//  LevelPickStep.swift
//  SnapLingo
//
//  引导里的水平选择：自己从 4 档里挑一个，不做测试。
//  选的档只决定一开始的推荐难度，之后复习和选词的表现会慢慢校准（LevelService）；
//  「我的」里还可以重新做小测（LevelTestView）。
//

import SwiftUI

/// 自评的 4 档，各自对应一个 CEFR 等级的中间分
enum SelfLevel: Int, CaseIterable, Identifiable {
    case beginner, elementary, intermediate, advanced

    var id: Int { rawValue }

    var cefr: CEFRLevel {
        switch self {
        case .beginner:     .a1
        case .elementary:   .a2
        case .intermediate: .b1
        case .advanced:     .b2
        }
    }

    var title: String {
        switch self {
        case .beginner:     String(localized: "零基础", comment: "Self-assessed English level: beginner")
        case .elementary:   String(localized: "初级", comment: "Self-assessed English level: elementary")
        case .intermediate: String(localized: "中级", comment: "Self-assessed English level: intermediate")
        case .advanced:     String(localized: "高级水平", comment: "Self-assessed English level: advanced")
        }
    }

    var detail: String {
        switch self {
        case .beginner:     String(localized: "刚开始学", comment: "Self-assessed level hint: beginner")
        case .elementary:   String(localized: "能简单对话", comment: "Self-assessed level hint: elementary")
        case .intermediate: String(localized: "越来越有信心", comment: "Self-assessed level hint: intermediate")
        case .advanced:     String(localized: "用英语很自在", comment: "Self-assessed level hint: advanced")
        }
    }

    /// 4 只小鸟：普通 → 开口说 → 看书 → 戴学士帽
    var icon: String { "LevelBird\(rawValue + 1)" }

    /// 已有分数最接近哪一档（「我的」里改过水平再进来时用）
    static func nearest(to score: Double) -> SelfLevel? {
        allCases.min { abs($0.cefr.midScore - score) < abs($1.cefr.midScore - score) }
    }
}

struct LevelPickStep: View {
    var onPick: (SelfLevel) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 和参考图一样默认选中第一档：宁可一开始的词偏简单，也不要一上来就太难
    @State private var selection: SelfLevel = .beginner
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("你现在的英语水平？")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.homeInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("我们会按你的水平挑例子，之后随时可以改。")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.homeInk.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, Spacing.xl)
            .padding(.horizontal, Spacing.md)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(motion(.smooth(duration: 0.5), delay: 0), value: appeared)

            VStack(spacing: 12) {
                ForEach(SelfLevel.allCases) { level in
                    LevelRow(level: level, selected: selection == level) {
                        withAnimation(.snappy(duration: 0.25)) { selection = level }
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(motion(.spring(response: 0.5, dampingFraction: 0.8), delay: 0.12 + 0.06 * Double(level.rawValue)), value: appeared)
                }
            }
            .padding(.top, 28)
            .sensoryFeedback(.selection, trigger: selection)

            Spacer(minLength: Spacing.lg)

            PrimaryButton(title: "继续", trailingSymbol: "arrow.right") { onPick(selection) }
        }
        .padding(Spacing.lg)
        .background { Theme.cream.ignoresSafeArea() }
        // 和欢迎页一样固定浅色：黑线小鸟、奶油底、黄色选中
        .environment(\.colorScheme, .light)
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

    private func motion(_ animation: Animation, delay: Double) -> Animation? {
        reduceMotion ? nil : animation.delay(delay)
    }
}

/// 一档：小鸟 + 名字和说明 + 单选圈；选中时整行变成奶黄色
private struct LevelRow: View {
    var level: SelfLevel
    var selected: Bool
    var action: () -> Void

    /// 参考图里的奶黄（比荧光笔浅）和米色
    private static let selectedFill = Color(hex: 0xF7E2A1)
    private static let fill = Color(hex: 0xF0E8D9)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(level.icon)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(Theme.homeInk)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(level.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.homeInk)
                    Text(level.detail)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.homeInk.opacity(0.75))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)

                Spacer(minLength: 8)

                ZStack {
                    Circle()
                        .strokeBorder(Theme.homeInk, lineWidth: selected ? 2 : 1.5)
                    Circle()
                        .fill(Theme.homeInk)
                        .padding(5)
                        .scaleEffect(selected ? 1 : 0.01)
                        .opacity(selected ? 1 : 0)
                }
                .frame(width: 22, height: 22)
            }
            .padding(.leading, 16)
            .padding(.trailing, 20)
            .frame(height: 72)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Self.selectedFill : Self.fill, in: .rect(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
