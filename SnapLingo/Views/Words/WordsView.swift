//
//  WordsView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

/// 词库：从复习页进入的二级页面（筛选只是熟悉程度，不是另一种复习方式）
struct WordsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \VocabWord.addedAt, order: .reverse) private var words: [VocabWord]
    @State private var query = ""
    @State private var filter: WordsFilter
    @FocusState private var searchFocused: Bool
    @State private var didAutoFocus = false
    private let startsSearching: Bool

    init(initialFilter: WordsFilter = .all, startsSearching: Bool = false) {
        _filter = State(initialValue: initialFilter)
        self.startsSearching = startsSearching
    }

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
        List {
            if !words.isEmpty {
                filterBar
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: Spacing.lg, bottom: 8, trailing: Spacing.lg))
            }

            if words.isEmpty {
                ContentUnavailableView(
                    "词库还是空的",
                    systemImage: "book.closed",
                    description: Text("扫描一个场景，挑几个词保存下来，它们就会出现在这里。")
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else if filtered.isEmpty {
                Group {
                    if query.isEmpty {
                        ContentUnavailableView("这里还没有词", systemImage: "tray", description: Text(emptyDescription))
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
                        RoundedRectangle(cornerRadius: Radius.card - 6, style: .continuous)
                            .fill(Theme.sheet)
                            .padding(.vertical, 4)
                            .padding(.horizontal, Spacing.lg)
                    )
                    .listRowInsets(EdgeInsets(top: 12, leading: Spacing.lg + Spacing.sm, bottom: 12, trailing: Spacing.lg + Spacing.sm))
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
        .background(Theme.cream.ignoresSafeArea())
        .scrollDismissesKeyboard(.immediately)
        // 自己的搜索框钉在导航栏下面：系统的 .searchable 一激活会把导航栏收起来，整页往上跳
        .safeAreaInset(edge: .top, spacing: 0) {
            if !words.isEmpty {
                searchField
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .background(Theme.cream)
            }
        }
        .navigationTitle("词库")
        .sensoryFeedback(.selection, trigger: filter)
        .task {
            // 从复习页的放大镜进来：等 push 动画走完再聚焦，不然焦点会丢
            guard startsSearching, !didAutoFocus else { return }
            didAutoFocus = true
            try? await Task.sleep(for: .milliseconds(600))
            searchFocused = true
        }
    }

    private var searchField: some View {
        HStack(spacing: Spacing.xs) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.homeInk)
                TextField("搜索单词或释义", text: $query)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.homeInk)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(Theme.homeMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清除")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Theme.homeInk.opacity(0.06), in: .capsule)
            .contentShape(.capsule)
            .onTapGesture { searchFocused = true }

            if searchFocused {
                Button("取消") {
                    query = ""
                    searchFocused = false
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.homeInk)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: searchFocused)
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.xs) {
                ForEach(WordsFilter.allCases) { item in
                    FilterChip(title: item.title, count: count(item), isSelected: filter == item) {
                        withAnimation(.snappy) { filter = item }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    private var emptyDescription: String {
        switch filter {
        case .all: ""
        case .new: String(localized: "所有保存的词都已经开始学了。")
        case .learning: String(localized: "开始今日学习后，词会出现在这里。")
        case .mastered: String(localized: "复习间隔超过 21 天或手动标记的词会出现在这里。")
        }
    }
}
