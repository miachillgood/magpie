//
//  LibraryView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(sort: \VocabWord.addedAt, order: .reverse) private var allWords: [VocabWord]
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager

    @State private var viewModel = LibraryViewModel()

    private var userWords: [VocabWord] {
        allWords.owned(by: authManager.currentUserID)
    }

    private var filtered: [VocabWord] { viewModel.filtered(userWords) }
    private var dueWords: [VocabWord] { userWords.filter(\.isDueForReview) }
    private var dueCount: Int { dueWords.count }
    private var masteredCount: Int { userWords.filter(\.isMastered).count }

    private var reviewStats: [LibraryReviewStat] {
        var groups: [String: [VocabWord]] = [:]
        for word in userWords { groups[word.categoryName, default: []].append(word) }
        return groups.map { name, words in
            LibraryReviewStat(categoryName: name, words: words)
        }
        .sorted {
            if $0.dueCount == $1.dueCount {
                return $0.totalCount > $1.totalCount
            }
            return $0.dueCount > $1.dueCount
        }
    }

    private var dueCategoryStats: [LibraryReviewStat] {
        reviewStats.filter { $0.dueCount > 0 }
    }

    var body: some View {
        Group {
            if userWords.isEmpty {
                emptyState
            } else {
                wordList
            }
        }
        .navigationTitle("我的词库")
        .searchable(text: $viewModel.searchText, prompt: "搜索单词或中文")
        .toolbar { toolbarContent }
        .navigationDestination(for: VocabWord.self) { word in
            WordDetailView(
                words: [word.word],
                sourceImage: word.sourceImageThumbnail.flatMap { UIImage(data: $0) },
                sceneTag: word.sceneTag,
                ocrText: word.exampleSentence,
                categoryName: word.categoryName
            )
        }
    }

    // MARK: - 列表

    private var wordList: some View {
        List {
            reviewSections

            let categories = viewModel.allCategories(from: userWords)
            if !categories.isEmpty {
                Section("按分类查看") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            categoryChip(nil, label: "全部")
                            ForEach(categories, id: \.self) { category in
                                categoryChip(category, label: category)
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                }
            }

            Section("\(filtered.count) 个词汇") {
                ForEach(filtered) { word in
                    NavigationLink(value: word) {
                        VocabWordRowView(word: word)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            modelContext.delete(word)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }

                        Button {
                            let willBeMastered = !word.isMastered
                            word.isMastered = willBeMastered

                            if willBeMastered {
                                try? LearningProfileStore.updateFamiliarity(
                                    normalizedForm: word.normalizedForm,
                                    ownerUserID: word.ownerUserID,
                                    signal: 0.95,
                                    source: .mastery,
                                    context: modelContext
                                )
                            }
                        } label: {
                            Label(
                                word.isMastered ? "取消掌握" : "已掌握",
                                systemImage: word.isMastered ? "xmark.seal" : "checkmark.seal"
                            )
                        }
                        .tint(.green)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var reviewSections: some View {
        Section("复习中心") {
            HStack(spacing: 0) {
                overviewCell(value: "\(userWords.count)", label: "总词汇", color: .blue)
                Divider().frame(height: 36)
                overviewCell(value: "\(dueCount)", label: "待复习", color: .orange)
                Divider().frame(height: 36)
                overviewCell(value: "\(masteredCount)", label: "已掌握", color: .green)
            }
            .padding(.vertical, 8)

            if dueWords.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("今天没有待复习词汇")
                            .font(.subheadline.weight(.medium))
                        Text("继续扫描新词，之后也可以回到这里开始复习。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } else {
                NavigationLink {
                    FlashcardReviewView(
                        categoryName: "全部复习",
                        wordsToReview: dueWords
                    )
                } label: {
                    allReviewRow
                }
            }
        }

        if !dueCategoryStats.isEmpty {
            Section("分类复习") {
                ForEach(dueCategoryStats) { stat in
                    NavigationLink {
                        FlashcardReviewView(
                            categoryName: stat.categoryName,
                            wordsToReview: stat.dueWords
                        )
                    } label: {
                        categoryReviewRow(stat)
                    }
                }
            }
        }
    }

    private func overviewCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var allReviewRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("开始复习")
                    .font(.headline)
                Text("混合全部分类，\(dueCount) 词待复习")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            reviewBadge(dueCount, color: .accentColor)
        }
        .padding(.vertical, 4)
    }

    private func categoryReviewRow(_ stat: LibraryReviewStat) -> some View {
        HStack(spacing: 12) {
            Image(systemName: stat.words.first?.sceneTag.icon ?? "tag")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(stat.categoryName)
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 8) {
                    Text("\(stat.totalCount) 词")
                    Text("·")
                    Text("\(stat.masteredCount) 已掌握")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            reviewBadge(stat.dueCount, color: .orange)
        }
        .padding(.vertical, 4)
    }

    private func reviewBadge(_ count: Int, color: Color) -> some View {
        Text("\(count)")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color, in: Capsule())
    }

    // MARK: - 分类过滤芯片

    private func categoryChip(_ category: String?, label: String) -> some View {
        let selected = viewModel.selectedCategory == category
        return Button {
            viewModel.selectedCategory = category
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 空状态

    private var emptyState: some View {
        ContentUnavailableView(
            "词库为空",
            systemImage: "books.vertical",
            description: Text("从扫描页拍照并保存词汇后，在这里查看、管理和复习")
        )
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker("排序方式", selection: $viewModel.sortOrder) {
                    ForEach(LibrarySortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
        }
    }
}

private struct LibraryReviewStat: Identifiable {
    let id = UUID()
    let categoryName: String
    let words: [VocabWord]

    var dueWords: [VocabWord] { words.filter(\.isDueForReview) }
    var dueCount: Int { dueWords.count }
    var masteredCount: Int { words.filter(\.isMastered).count }
    var totalCount: Int { words.count }
}
