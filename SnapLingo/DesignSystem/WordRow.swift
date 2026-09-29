//
//  WordRow.swift
//  SnapLingo
//

import SwiftUI

/// 单词行：场景 emoji + 衬线单词 + 释义，右侧难度和状态
struct WordRow: View {
    var word: VocabWord
    var showsScene = true

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if showsScene {
                let scene = word.latestScan?.scene ?? .general
                EmojiTile(emoji: scene.emoji, color: scene.pastel, size: 46)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(word.word)
                        .font(.word(19, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if !word.partOfSpeech.isEmpty {
                        Text(word.partOfSpeech)
                            .font(.caption.italic())
                            .foregroundStyle(.secondary)
                    }
                }
                Text(word.meaning.isEmpty ? "正在生成解释…" : word.meaning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.xs)

            VStack(alignment: .trailing, spacing: 5) {
                CEFRBadge(level: word.cefr)
                stateIndicator
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var stateIndicator: some View {
        switch word.state {
        case .new:
            Text("待学")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        case .learning:
            if word.dueDate <= Calendar.current.startOfDay(for: Date()) && !word.excludedFromReview {
                Text("今天复习")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(Theme.brand)
            } else {
                Text(word.dueDate, format: .dateTime.month().day())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        case .mastered:
            Text("🏅")
                .font(.caption)
                .accessibilityLabel("已掌握")
        }
    }
}
