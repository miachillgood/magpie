//
//  WordsView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

struct WordsView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var context
    @Query(sort: \VocabWord.addedAt, order: .reverse) private var words: [VocabWord]
    @State private var query = ""
    @Namespace private var zoom

    private var filter: WordsFilter { coordinator.wordsFilter }

    private var filtered: [VocabWord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = words.filter { word in
            filter.matches(word) && (trimmed.isEmpty
                || word.word.localizedCaseInsensitiveContains(trimmed)
                || word.meaning.localizedCaseInsensitiveContains(trimmed))
        }
        switch filter {
        case .learning: return matching.sorted { $0.dueDate < $1.dueDate }
        case .mastered: return matching.sorted { $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending }
        default: return matching
        }
    }

    private func count(_ filter: WordsFilter) -> Int {
        words.filter(filter.matches).count
    }

    var body: some View {
        NavigationStack {
            List {
                if !words.isEmpty {
                    filterBar
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: Spacing.lg, bottom: 8, trailing: Spacing.lg))
                }

                if words.isEmpty {
                    IllustratedEmptyState(
                        emoji: "📚",
                        color: Pastel.butter,
                        title: "词库还是空的",
                        message: "扫描一个场景，挑几个词保存下来，它们就会出现在这里。",
                        buttonTitle: "去扫描"
                    ) { coordinator.startScan() }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else if filtered.isEmpty {
                    Group {
                        if query.isEmpty {
                            IllustratedEmptyState(emoji: filterEmoji, color: Pastel.sand, title: "这里还没有词", message: emptyDescription)
                        } else {
                            ContentUnavailableView.search(text: query)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(filtered) { word in
                        NavigationLink(value: word) {
                            WordRow(word: word)
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: Radius.card - 4, style: .continuous)
                                .fill(Theme.card)
                                .padding(.vertical, 4)
                                .padding(.horizontal, Spacing.lg)
                        )
                        .listRowInsets(EdgeInsets(top: 14, leading: Spacing.lg + Spacing.sm, bottom: 14, trailing: Spacing.lg + Spacing.sm))
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing) {
                            Button("删除", systemImage: "trash", role: .destructive) {
                                WordLibrary.delete(word, context: context)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if word.excludedFromReview {
                                Button("恢复复习", systemImage: "arrow.uturn.backward") {
                                    WordLibrary.setMastered(word, false, context: context)
                                }
                                .tint(Theme.reviews)
                            } else {
                                Button("已掌握", systemImage: "checkmark.seal") {
                                    WordLibrary.setMastered(word, true, context: context)
                                }
                                .tint(Theme.success)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(PaperBackground())
            .searchable(text: $query, prompt: "搜索单词或释义")
            .navigationTitle("词库")
            .appTabBar()
            .libraryDestinations(zoom: zoom)
            .sensoryFeedback(.selection, trigger: coordinator.wordsFilter)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.xs) {
                ForEach(WordsFilter.allCases) { item in
                    FilterChip(title: item.title, emoji: emoji(for: item), count: count(item), isSelected: filter == item) {
                        withAnimation(.snappy) { coordinator.wordsFilter = item }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    private func emoji(for filter: WordsFilter) -> String? {
        switch filter {
        case .all: nil
        case .new: WordState.new.emoji
        case .learning: WordState.learning.emoji
        case .mastered: WordState.mastered.emoji
        }
    }

    private var filterEmoji: String { emoji(for: filter) ?? "📚" }

    private var emptyDescription: String {
        switch filter {
        case .all: ""
        case .new: "所有保存的词都已经开始学了。"
        case .learning: "开始今日学习后，词会出现在这里。"
        case .mastered: "复习间隔超过 21 天或手动标记的词会出现在这里。"
        }
    }
}
