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

    /// 4 只蜡笔小鸟：趴着 → 满头问号 → 爬楼梯 → 戴墨镜
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
        GeometryReader { proxy in
            let width = proxy.size.width
            let compact = proxy.size.height < 700
            VStack(spacing: 0) {
                header(width: width, compact: compact)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(motion(.smooth(duration: 0.5), delay: 0), value: appeared)

                VStack(spacing: compact ? 8 : 12) {
                    ForEach(SelfLevel.allCases) { level in
                        LevelRow(level: level, selected: selection == level, compact: compact) {
                            withAnimation(.snappy(duration: 0.25)) { selection = level }
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(motion(.spring(response: 0.5, dampingFraction: 0.8), delay: 0.12 + 0.06 * Double(level.rawValue)), value: appeared)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, compact ? 16 : 28)
                .sensoryFeedback(.selection, trigger: selection)

                Spacer(minLength: 12)

                footer(width: width)
                    .opacity(appeared ? 1 : 0)
                    .animation(motion(.easeOut(duration: 0.5), delay: 0.45), value: appeared)
            }
            .frame(width: width, height: proxy.size.height, alignment: .top)
        }
        .background { Theme.sketchPaper.ignoresSafeArea() }
        // 和欢迎页一样固定浅色：蜡笔小鸟、米白纸底、黄色选中
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

    /// 手写标题图（和介绍页一样所有语言都用英文），下面一句手写说明
    private func header(width: CGFloat, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            Image("LevelTitle")
                .resizable()
                .scaledToFit()
                .frame(width: min(width * 0.78, 340))
                .accessibilityLabel(Text("你现在的英语水平？"))
                .accessibilityAddTraits(.isHeader)
            // 手写的说明图，和标题一样所有语言都用英文
            Image("LevelSubtitle")
                .resizable()
                .scaledToFit()
                .frame(width: min(width * (compact ? 0.72 : 0.78), 320))
                .accessibilityLabel(Text("我们会按你的水平挑例子，之后随时可以改。"))
                .rotationEffect(.degrees(-2))
                .padding(.leading, width * 0.06)
                .padding(.trailing, 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, width * 0.08)
        .padding(.top, compact ? 4 : 20)
    }

    /// 按钮左边两颗小石子，右边一只戴帽子的小鸟跑过来
    private func footer(width: CGFloat) -> some View {
        ContinueSketchButton { onPick(selection) }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottomLeading) {
                Image("LevelDots")
                    .resizable()
                    .scaledToFit()
                    .frame(width: width * 0.12)
                    .padding(.leading, width * 0.06)
                    .offset(y: 14)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .bottomTrailing) {
                Image("LevelRunner")
                    .resizable()
                    .scaledToFit()
                    .frame(width: width * 0.17)
                    .padding(.trailing, width * 0.03)
                    .offset(y: 12)
                    .accessibilityHidden(true)
            }
            .padding(.bottom, 20)
    }

    private func motion(_ animation: Animation, delay: Double) -> Animation? {
        reduceMotion ? nil : animation.delay(delay)
    }
}

/// 一档：蜡笔小鸟 + 手写的名字和说明 + 单选圈；选中时整行变成蜡笔黄
private struct LevelRow: View {
    var level: SelfLevel
    var selected: Bool
    var compact: Bool
    var action: () -> Void

    /// 参考图里的蜡笔黄和比纸底深一点的米色
    private static let selectedFill = Color(hex: 0xFCEFA0)
    private static let fill = Color(hex: 0xF5F0E3)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(level.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: compact ? 52 : 60)

                VStack(alignment: .leading, spacing: 0) {
                    // 系统自带的 Chalkboard SE Light 手写体
                    Text(level.title)
                        .font(.custom("ChalkboardSE-Light", size: compact ? 18 : 20))
                        .foregroundStyle(Theme.homeInk)
                    Text(level.detail)
                        .font(.custom("ChalkboardSE-Light", size: compact ? 12 : 13))
                        .foregroundStyle(Theme.homeInk.opacity(0.75))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)

                Spacer(minLength: 8)

                ZStack {
                    Circle()
                        .strokeBorder(Theme.homeInk, lineWidth: 2)
                    Circle()
                        .fill(Theme.homeInk)
                        .padding(6)
                        .scaleEffect(selected ? 1 : 0.01)
                        .opacity(selected ? 1 : 0)
                }
                .frame(width: 24, height: 24)
            }
            .padding(.leading, 12)
            .padding(.trailing, 20)
            .frame(height: compact ? 70 : 80)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Self.selectedFill : Self.fill, in: .rect(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
