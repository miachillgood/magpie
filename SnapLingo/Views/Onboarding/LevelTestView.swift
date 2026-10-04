//
//  LevelTestView.swift
//  SnapLingo
//

import SwiftUI

/// 2 轮“点你认识的词”，完成后显示结果
struct LevelTestView: View {
    var onSkip: (() -> Void)? = nil
    var onFinish: (Double) -> Void

    @State private var test = LevelTest()
    @State private var items: [LevelTest.Item] = []
    @State private var known: Set<String> = []
    @State private var finished = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 标题和说明先出来
    @State private var appeared = false
    /// 读完说明再出单词：等于当前轮次时这一轮的词才显示
    @State private var shownRound = -1

    var body: some View {
        ZStack {
            OnboardingBackground()
            Group {
                if finished {
                    result
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    round
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .animation(.smooth, value: finished)
        .onAppear {
            if items.isEmpty { items = test.nextRound() }
            if Self.debugResultLevel != nil { finished = true }
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
                shownRound = test.round
            } else {
                Task {
                    try? await Task.sleep(for: .milliseconds(80))
                    appeared = true
                    try? await Task.sleep(for: .milliseconds(650))
                    shownRound = test.round
                }
            }
        }
        .sensoryFeedback(.selection, trigger: known)
    }

    // MARK: - 一轮

    private var round: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    ForEach(0..<LevelTest.rounds, id: \.self) { index in
                        Capsule()
                            .fill(index <= test.round ? Theme.homeInk : Theme.homeInk.opacity(0.12))
                            .frame(height: 6)
                    }
                }
                .animation(.smooth, value: test.round)
                // 跳过做得不显眼：大多数人应该测一下，但不会卡住完全不会的人
                if let onSkip {
                    Button("跳过", action: onSkip)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.homeMuted)
                }
            }
            .frame(minHeight: 32)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(test.round == 0 ? "先测一下你的英语水平" : "最后一轮")
                    .font(.system(size: 30, weight: .heavy))
                    .contentTransition(.opacity)
                Text(test.round == 0
                     ? "点你认识的词，大约 30 秒，一共 2 轮。不确定就别选，结果会更准。"
                     : "按刚才的结果换了一组词，还是点你认识的。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .modifier(Entrance(appeared: appeared, delay: 0.12, reduceMotion: reduceMotion))
            }
            .modifier(Entrance(appeared: appeared, delay: 0, reduceMotion: reduceMotion))

            FlowLayout(spacing: Spacing.sm) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let isOn = known.contains(item.word)
                    let shown = shownRound == test.round
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            if isOn { known.remove(item.word) } else { known.insert(item.word) }
                        }
                    } label: {
                        Text(item.word)
                            .font(.word(22, weight: .bold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .foregroundStyle(isOn ? Theme.onInk : Theme.ink)
                            .background(isOn ? Theme.ink : Theme.card, in: .capsule)
                            .overlay(Capsule().strokeBorder(isOn ? .clear : Theme.hairline))
                            .softShadow(isOn ? 1 : 0.5)
                            .scaleEffect(isOn ? 1.04 : 1)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    // 一个接一个冒出来
                    .opacity(shown ? 1 : 0)
                    .scaleEffect(shown ? 1 : 0.85)
                    .offset(y: shown ? 0 : 10)
                    .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.75).delay(0.05 * Double(index)), value: shown)
                    .allowsHitTesting(shown)
                }
            }
            .id(test.round)
            .transition(.opacity)

            Spacer()

            VStack(spacing: Spacing.lg) {
                Text(known.isEmpty ? "一个都不认识也没关系 🙂" : "已选 \(known.count) 个")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())

                PrimaryButton(title: test.round + 1 < LevelTest.rounds ? "下一轮" : "看结果", trailingSymbol: "arrow.right") {
                    advance()
                }
            }
            .modifier(Entrance(appeared: appeared, delay: 0.25, reduceMotion: reduceMotion))
        }
        .padding(Spacing.lg)
    }

    private func advance() {
        // 词还没出来就点“下一轮”，等于什么都没看就交了
        guard shownRound == test.round else { return }
        test.submit(items, known: known)
        known = []
        if test.isFinished {
            finished = true
        } else {
            withAnimation(.smooth) { items = test.nextRound() }
            // 第二轮也是先换标题说明，再出新词
            if reduceMotion {
                shownRound = test.round
            } else {
                let round = test.round
                Task {
                    try? await Task.sleep(for: .milliseconds(550))
                    shownRound = round
                }
            }
        }
    }

    // MARK: - 结果

    private var result: some View {
        LevelResultView(level: Self.debugResultLevel ?? test.estimatedLevel) {
            onFinish(Self.debugResultLevel?.midScore ?? test.score)
        }
    }

    /// 截图用：启动参数 -levelResult A1 直接打开结果页
    @MainActor private static var debugResultLevel: CEFRLevel? {
        #if DEBUG
        OnboardingDebug.value(after: "-levelResult").flatMap(CEFRLevel.init(code:))
        #else
        nil
        #endif
    }
}
