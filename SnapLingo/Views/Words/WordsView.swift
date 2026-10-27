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
    @State private var searching = false
    /// 左滑删除先确认（和词夹里的删除一致）
    @State private var pendingDelete: VocabWord?
    @State private var deletedCount = 0
    /// 词库里没有的词：查一查，看了释义再加入复习
    @State private var lookup: LookupTerm?
    /// 说一说：念一个词就查词，说一段话就推荐这个场景的词
    @State private var speaking = false
    private let startsSearching: Bool

    init(initialFilter: WordsFilter = .all, startsSearching: Bool = false) {
        _filter = State(initialValue: initialFilter)
        // 从放大镜进来：搜索框一开始就是激活的，跟着页面一起出现（不要等动画走完再跳一下）
        _searching = State(initialValue: startsSearching)
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

    /// 搜的是一个英文词、词库里又没有完全一样的：给一个「查一查」
    private var lookupTerm: String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard WordLookupSheet.isLookupQuery(trimmed) else { return nil }
        let key = trimmed.normalizedWordKey
        return words.contains { $0.normalizedForm == key } ? nil : trimmed
    }

    private func count(_ filter: WordsFilter) -> Int {
        words.filter(filter.matches).count
    }

    var body: some View {
        List {
            if let lookupTerm {
                LookupRow(term: lookupTerm) { lookup = LookupTerm(text: lookupTerm) }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: Spacing.lg, bottom: 8, trailing: Spacing.lg))
            }

            if !words.isEmpty {
                filterBar
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: Spacing.lg, bottom: 8, trailing: Spacing.lg))
            }

            if words.isEmpty, lookupTerm == nil {
                ContentUnavailableView(
                    "词库还是空的",
                    systemImage: "book.closed",
                    description: Text("扫描一个场景，挑几个词保存下来，它们就会出现在这里。")
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else if filtered.isEmpty, lookupTerm == nil {
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
                            pendingDelete = word
                        }
                    }
                    .contextMenu {
                        Button("读一遍", systemImage: "speaker.wave.2") {
                            SpeechService.shared.speak(word.word)
                        }
                        if word.excludedFromReview {
                            Button("恢复复习", systemImage: "arrow.uturn.backward") {
                                WordLibrary.setMastered(word, false, context: context)
                            }
                        } else {
                            Button("标记为已掌握", systemImage: "checkmark.seal") {
                                WordLibrary.setMastered(word, true, context: context)
                            }
                        }
                        Divider()
                        Button("删除", systemImage: "trash", role: .destructive) {
                            pendingDelete = word
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
        .navigationTitle("词库")
        // 系统搜索框：一直显示在导航栏下面，激活时不收起导航栏和筛选
        .searchable(text: $query, isPresented: $searching, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("搜索单词或释义"))
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .sensoryFeedback(.selection, trigger: filter)
        .sheet(item: $lookup) { term in
            WordLookupSheet(query: term.text)
        }
        .sheet(isPresented: $speaking) {
            VoiceCaptureSheet { word in
                query = word
                // 等语音面板收起来再弹查词面板
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    lookup = LookupTerm(text: word)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("说一说", systemImage: "mic") { speaking = true }
                    .tint(Theme.homeInk)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: deletedCount)
        .confirmationDialog(
            "删除“\(pendingDelete?.word ?? "")”？",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                guard let word = pendingDelete else { return }
                withAnimation { WordLibrary.delete(word, context: context) }
                deletedCount += 1
            }
        } message: {
            Text("复习记录也会一起删掉。")
        }
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

private struct LookupTerm: Identifiable {
    let id = UUID()
    let text: String
}

/// 搜索结果最上面的「查一查 “oat”」
private struct LookupRow: View {
    var term: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.homeInk)
                    .frame(width: 34, height: 34)
                    .background(Theme.streakFill, in: .circle)
                VStack(alignment: .leading, spacing: 1) {
                    Text("查一查 “\(term)”", comment: "Look up a word that is not in the library yet")
                        .font(.headline)
                        .foregroundStyle(Theme.homeInk)
                    Text("看释义，再决定要不要加入复习")
                        .font(.caption)
                        .foregroundStyle(Theme.homeMuted)
                }
                .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.homeMuted)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 10)
            .background(Theme.sheet, in: .rect(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.pressable)
    }
}
