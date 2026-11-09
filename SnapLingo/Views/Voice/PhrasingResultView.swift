//
//  PhrasingResultView.swift
//  SnapLingo
//
//  「说一说」里问「这句话怎么说」的结果：2–3 种地道说法，能听、能加入复习。
//

import SwiftUI
import SwiftData

struct PhrasingResultView: View {
    var transcript: String
    var result: PhrasingResult
    var onRetry: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    /// 已经加进复习的说法
    @State private var added: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("你想说")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Theme.homeMuted)
                    Text(verbatim: result.situation.isEmpty ? transcript : result.situation)
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(Theme.homeInk)
                }
                .padding(.top, Spacing.sm)

                ForEach(result.phrasings) { phrasing in
                    PhrasingCard(phrasing: phrasing, isAdded: added.contains(phrasing.id)) {
                        add(phrasing)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .background(Theme.cream.ignoresSafeArea())
        .navigationTitle("怎么说")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: added.count)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("重说", systemImage: "arrow.counterclockwise", action: onRetry)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成", systemImage: "checkmark") { dismiss() }
            }
        }
        .task {
            // 已经存过的说法一进来就标成「已加入」
            let keys = Set(StudyStore.words(context).map(\.normalizedForm))
            added = Set(result.phrasings.filter { keys.contains($0.text.normalizedWordKey) }.map(\.id))
        }
    }

    private func add(_ phrasing: Phrasing) {
        WordLibrary.addPhrase(phrasing, situation: result.situation, context: context)
        StudyReminder.refresh(context: context)
        withAnimation(.snappy) { _ = added.insert(phrasing.id) }
    }
}

/// 一种说法：英文整句 + 语气 + 翻译 + 提示，右边是朗读和加入复习
private struct PhrasingCard: View {
    var phrasing: Phrasing
    var isAdded: Bool
    var onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tone)
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Theme.homeInk.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(toneColor, in: .capsule)
                    Text(verbatim: phrasing.text)
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(Theme.homeInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    if !phrasing.translation.isEmpty {
                        Text(verbatim: phrasing.translation)
                            .font(.subheadline)
                            .foregroundStyle(Theme.homeMuted)
                    }
                }
                Spacer(minLength: 0)
                SpeakButton(text: phrasing.text, size: 40)
            }
            if !phrasing.note.isEmpty {
                Text(verbatim: "💡 \(phrasing.note)")
                    .font(.footnote)
                    .foregroundStyle(Theme.homeInk.opacity(0.8))
            }
            Button(action: onAdd) {
                Label(isAdded ? "已加入复习" : "加入复习", systemImage: isAdded ? "checkmark" : "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isAdded ? Theme.homeMuted : Theme.homeInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isAdded ? Theme.insetFill : Theme.streakFill, in: .capsule)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pressable)
            .disabled(isAdded)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.sheet, in: .rect(cornerRadius: 20, style: .continuous))
    }

    private var tone: String {
        switch phrasing.tone {
        case .casual: String(localized: "随意", comment: "Tone of a suggested English sentence: casual")
        case .neutral: String(localized: "一般", comment: "Tone of a suggested English sentence: neutral")
        case .polite: String(localized: "礼貌", comment: "Tone of a suggested English sentence: polite")
        }
    }

    private var toneColor: Color {
        switch phrasing.tone {
        case .casual: Pastel.mint
        case .neutral: Pastel.sky
        case .polite: Pastel.peach
        }
    }
}
