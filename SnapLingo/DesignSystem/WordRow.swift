//
//  WordRow.swift
//  SnapLingo
//

import SwiftUI

/// 单词行：场景线条图标 + 衬线单词 + 释义，右侧状态
struct WordRow: View {
    var word: VocabWord
    var showsScene = true

    @AppStorage(AIConsent.storageKey) private var consentRaw = AIConsent.State.undecided.rawValue

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if showsScene {
                IconImage(name: SceneType.of(word).iconName, size: 28)
                    .frame(width: 44, height: 44)
                    .background(Theme.placeChip, in: .rect(cornerRadius: 13, style: .continuous))
                    .accessibilityHidden(true)
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
                Text(word.meaning.isEmpty ? (consentRaw == AIConsent.State.granted.rawValue ? String(localized: "正在生成解释…") : String(localized: "AI 释义已关闭")) : word.meaning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.xs)

            stateIndicator
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
                    .foregroundStyle(Theme.homeInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.marker, in: .capsule)
            } else {
                Text(word.dueDate, format: .dateTime.month().day())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        case .mastered:
            Text("已掌握")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
    }
}
