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
    @State private var selection: SelfLevel?
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Text("你现在的英语水平？")
                    .font(.brand(30))
                    .foregroundStyle(Theme.homeInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("我们会按你的水平挑例子，之后随时可以改。")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.homeMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, Spacing.xl)
            .padding(.horizontal, Spacing.sm)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(motion(.smooth(duration: 0.5), delay: 0), value: appeared)

            Spacer(minLength: Spacing.lg)

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
            .sensoryFeedback(.selection, trigger: selection)

            Spacer(minLength: Spacing.lg)

            PrimaryButton(title: "继续", trailingSymbol: "arrow.right") {
                if let selection { onPick(selection) }
            }
            .disabled(selection == nil)
            .opacity(selection == nil ? 0.4 : 1)
            .animation(.smooth, value: selection == nil)
        }
        .padding(Spacing.lg)
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

/// 一档：小鸟图标 + 名字和说明 + 单选圈；选中时整行变黄
private struct LevelRow: View {
    var level: SelfLevel
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(level.icon)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(Theme.homeInk)
                    .padding(4)
                    .frame(width: 56, height: 56)
                    .background(selected ? Theme.sheet.opacity(0.7) : Theme.sheet, in: .rect(cornerRadius: 16, style: .continuous))
                    .scaleEffect(selected ? 1.06 : 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(level.title)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Theme.homeInk)
                    Text(level.detail)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.homeInk.opacity(0.65))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)

                Spacer(minLength: 8)

                ZStack {
                    Circle()
                        .strokeBorder(selected ? Theme.homeInk : Theme.homeInk.opacity(0.3), lineWidth: 2)
                    Circle()
                        .fill(Theme.homeInk)
                        .padding(5)
                        .scaleEffect(selected ? 1 : 0.01)
                        .opacity(selected ? 1 : 0)
                }
                .frame(width: 24, height: 24)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Theme.marker.opacity(0.7) : Theme.insetFill, in: .rect(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(selected ? Theme.homeInk.opacity(0.12) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
