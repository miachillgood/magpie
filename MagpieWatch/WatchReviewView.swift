//
//  WatchReviewView.swift
//  MagpieWatch
//
//  一张一张复习：正面是单词，点一下看意思，再选「不会 / 会」。
//  「不会」的词和手机上一样，隔 4 张再出现一次（最多 3 次），重练的结果不发回手机。
//  手表上没有「太简单」：屏幕小容易误触，而且它会把词移出复习。
//

import AVFoundation
import SwiftUI

struct WatchReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var queue: [Item]
    @State private var position = 0
    @State private var revealed = false
    /// 手表每评一张，首页的剩余卡片就少一张，这个页面会被重新创建：总数要存在 State 里，不能跟着变
    @State private var total: Int
    @State private var accent: String

    private static let retryGap = 4
    private static let maxAttempts = 3
    private static let speech = AVSpeechSynthesizer()

    private struct Item: Identifiable {
        let id = UUID()
        let card: WatchCard
        let attempt: Int
    }

    init(cards: [WatchCard]) {
        _queue = State(initialValue: cards.map { Item(card: $0, attempt: 0) })
        _total = State(initialValue: cards.count)
        _accent = State(initialValue: WatchStore.shared.snapshot?.accent ?? "en-US")
    }

    private var current: Item? { position < queue.count ? queue[position] : nil }
    /// 第几张新卡（重练的不算）
    private var seen: Int { min(queue.prefix(position + 1).filter { $0.attempt == 0 }.count, total) }

    var body: some View {
        Group {
            if let item = current {
                card(item)
                    .id(item.id)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
            } else {
                VStack(spacing: 8) {
                    Text(verbatim: "🎉")
                        .font(.largeTitle)
                    Text("复习完了")
                        .font(.headline)
                    Button("完成") { dismiss() }
                }
            }
        }
        .navigationTitle(Text(verbatim: "\(seen)/\(total)"))
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: revealed)
    }

    // MARK: - 卡片

    private func card(_ item: Item) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: item.card.word)
                        .font(.system(.title3, design: .serif, weight: .bold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    Button {
                        speak(item.card.word)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .accessibilityLabel(Text("朗读"))
                }
                if !item.card.phonetic.isEmpty {
                    Text(verbatim: item.card.phonetic)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if revealed {
                    back(item.card)
                } else {
                    Button {
                        withAnimation(.snappy) { revealed = true }
                    } label: {
                        Label("看意思", systemImage: "eye")
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 8)
                    Text(item.card.isNew ? "认识这个词吗？" : "还记得它的意思吗？")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)
        }
        // 「不会 / 会」固定在底部，不用转表冠去找
        .toolbar {
            if revealed {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button { rate(item, success: false) } label: {
                        Label("不会", systemImage: "xmark")
                    }
                    .tint(.red)
                    Spacer()
                    Button { rate(item, success: true) } label: {
                        Label("会", systemImage: "checkmark")
                    }
                    .tint(.green)
                }
            }
        }
    }

    @ViewBuilder
    private func back(_ card: WatchCard) -> some View {
        Divider().padding(.vertical, 2)
        if !card.meaning.isEmpty {
            Text(verbatim: card.meaning)
                .font(.body.weight(.semibold))
        }
        if !card.example.isEmpty {
            Text(verbatim: card.example)
                .font(.footnote.italic())
            if !card.exampleTranslation.isEmpty {
                Text(verbatim: card.exampleTranslation)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 动作

    private func rate(_ item: Item, success: Bool) {
        if item.attempt == 0 {
            WatchStore.shared.record(item.card, success: success)
        }
        if !success && item.attempt + 1 < Self.maxAttempts {
            let index = min(position + 1 + Self.retryGap, queue.count)
            queue.insert(Item(card: item.card, attempt: item.attempt + 1), at: index)
        }
        withAnimation(.snappy) {
            revealed = false
            position += 1
        }
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: accent)
        utterance.rate = 0.46
        Self.speech.stopSpeaking(at: .immediate)
        Self.speech.speak(utterance)
    }
}
