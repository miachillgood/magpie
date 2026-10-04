//
//  MistakeViews.swift
//  SnapLingo
//
//  错词重练：最近一次点了「不会」、还没答对的词（MeStats.mistakeWordIDs）。
//  复习页上一张入口卡片，点进去是整张列表，底部「开始重练」。练对了自动移出列表。
//  没有错词时入口不显示。
//

import SwiftUI
import SwiftData

/// 复习页上的入口：前几个错词做成贴纸，点卡片看全部，按钮直接开练
struct MistakesCard: View {
    var words: [VocabWord]
    var onStudy: () -> Void

    private static let fills: [Color] = [Theme.sheet, Theme.placeChip, Theme.sheet, Theme.marker.opacity(0.55), Theme.sheet]
    private static let rotations: [Double] = [-1.5, 1, -1, 1.5, -1]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NavigationLink(value: ReviewRoute.mistakes) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("错词重练")
                        .font(.headline.weight(.heavy))
                        .accessibilityAddTraits(.isHeader)
                    Text("\(words.count) 个词")
                        .font(.footnote)
                        .foregroundStyle(Theme.homeMuted)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.homeMuted)
                }
                .foregroundStyle(Theme.homeInk)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            FlowLayout(spacing: 8) {
                ForEach(Array(words.prefix(5).enumerated()), id: \.element.id) { index, word in
                    Text(verbatim: word.word)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.homeInk)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(Self.fills[index % 5], in: .capsule)
                        .overlay(Capsule().strokeBorder(Theme.homeInk.opacity(0.05)))
                        .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
                        .rotationEffect(.degrees(Self.rotations[index % 5]))
                }
                if words.count > 5 {
                    Text(verbatim: "+\(words.count - 5)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.homeMuted)
                        .padding(.vertical, 7)
                }
            }
            .accessibilityHidden(true)

            Button(action: onStudy) {
                HStack(spacing: 8) {
                    Text("开始重练")
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.cream)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Theme.homeInk, in: .capsule)
            }
            .buttonStyle(.pressable)
            .padding(.top, 2)
        }
        .padding(16)
        .background(Theme.sheet, in: .rect(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}

/// 全部错词：一行一个词和释义，点进去看详情；底部「开始重练」
struct MistakesView: View {
    @Query private var allWords: [VocabWord]
    @Environment(AppCoordinator.self) private var coordinator

    private var words: [VocabWord] {
        let ids = MeStats.mistakeWordIDs(allWords.map { MistakeRecord(id: $0.id, mistakeAt: $0.mistakeAt, excludedFromReview: $0.excludedFromReview) })
        let byID = Dictionary(allWords.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }
    }

    var body: some View {
        let words = words
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if words.isEmpty {
                    VStack(spacing: 10) {
                        Text("🎉").font(.system(size: 44))
                        Text("错词都练对了")
                            .font(.body.weight(.heavy))
                            .foregroundStyle(Theme.homeInk)
                        Text("复习时点了「不会」的词会出现在这里")
                            .font(.subheadline)
                            .foregroundStyle(Theme.homeMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    VStack(spacing: 10) {
                        ForEach(words) { word in
                            NavigationLink(value: word) {
                                MistakeRow(word: word)
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .background(Theme.mist.ignoresSafeArea())
        // 和同一栈里的词库、场景页一样用系统导航栏（返回按钮、边缘右滑）
        .navigationTitle("错词重练")
        .navigationSubtitle(Text("\(words.count) 个词"))
        .safeAreaInset(edge: .bottom) {
            if !words.isEmpty {
                PrimaryButton(title: "开始重练") {
                    coordinator.startStudy(.words(words.map(\.id)))
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xs)
            }
        }
    }
}

private struct MistakeRow: View {
    var word: VocabWord

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: word.word)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.homeInk)
                if !word.gloss.isEmpty {
                    Text(verbatim: word.gloss)
                        .font(.footnote)
                        .foregroundStyle(Theme.homeMuted)
                }
            }
            .lineLimit(1)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.homeInk.opacity(0.6))
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 62)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.sheet, in: .rect(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}
