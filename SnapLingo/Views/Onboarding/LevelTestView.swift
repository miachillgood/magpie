//
//  LevelTestView.swift
//  SnapLingo
//

import SwiftUI

/// 3 轮“点你认识的词”，完成后显示结果
struct LevelTestView: View {
    var onSkip: (() -> Void)? = nil
    var onFinish: (Double) -> Void

    @State private var test = LevelTest()
    @State private var items: [LevelTest.Item] = []
    @State private var known: Set<String> = []
    @State private var finished = false

    var body: some View {
        ZStack {
            PaperBackground()
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
        }
        .sensoryFeedback(.selection, trigger: known)
        .toolbar {
            if let onSkip, !finished {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("跳过", action: onSkip)
                        .foregroundStyle(Theme.ink)
                }
            }
        }
    }

    // MARK: - 一轮

    private var round: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(spacing: 6) {
                ForEach(0..<LevelTest.rounds, id: \.self) { index in
                    Capsule()
                        .fill(index <= test.round ? Theme.brand : Theme.ink.opacity(0.1))
                        .frame(height: 6)
                }
            }
            .animation(.smooth, value: test.round)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("你认识哪些词？")
                    .font(.display)
                Text("点选你知道意思的词。不确定就别选，结果会更准。")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            FlowLayout(spacing: Spacing.sm) {
                ForEach(items) { item in
                    let isOn = known.contains(item.word)
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
                }
            }
            .id(test.round)
            .transition(.opacity)

            Spacer()

            Text(known.isEmpty ? "一个都不认识也没关系 🙂" : "已选 \(known.count) 个")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText())

            PrimaryButton(title: test.round + 1 < LevelTest.rounds ? "下一轮" : "看结果", trailingSymbol: "arrow.right") {
                advance()
            }
        }
        .padding(Spacing.lg)
    }

    private func advance() {
        test.submit(items, known: known)
        known = []
        if test.isFinished {
            finished = true
        } else {
            withAnimation(.smooth) { items = test.nextRound() }
        }
    }

    // MARK: - 结果

    private var result: some View {
        let level = test.estimatedLevel
        return VStack(spacing: Spacing.lg) {
            Spacer()
            Text(level.code)
                .font(.system(size: 72, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .frame(width: 180, height: 180)
                .background(Pastel.lavender, in: .circle)
                .overlay(alignment: .topTrailing) {
                    Text("🎯").font(.system(size: 44)).offset(x: 8, y: -4)
                }
            VStack(spacing: Spacing.xs) {
                Text("你的水平：\(level.displayName)")
                    .font(.title.weight(.heavy))
                Text(level.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Text("✨ 扫描时会优先推荐 \(level.code)\(level.next.map { "–\($0.code)" } ?? "") 难度的词")
                .font(.subheadline.weight(.semibold))
                .card()
            Spacer()
            PrimaryButton(title: "好的", symbol: "checkmark") {
                onFinish(test.score)
            }
        }
        .padding(Spacing.lg)
        .sensoryFeedback(.success, trigger: finished)
    }
}
