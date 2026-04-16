//
//  LibraryView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(sort: \VocabWord.addedAt, order: .reverse) private var allWords: [VocabWord]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppCoordinator.self) private var coordinator

    @State private var viewModel = LibraryViewModel()

    private var filtered: [VocabWord] { viewModel.filtered(allWords) }
    private var dueCount: Int { viewModel.dueCount(allWords) }

    var body: some View {
        @Bindable var coordinator = coordinator

        Group {
            if allWords.isEmpty {
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
            // 复习提示 banner
            if dueCount > 0 {
                Section {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundStyle(.orange)
                        Text("有 **\(dueCount)** 个词待复习")
                        Spacer()
                        Button("去复习") {
                            coordinator.selectedTab = .review
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            }

            // 分类过滤芯片
            let categories = viewModel.allCategories(from: allWords)
            if !categories.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            categoryChip(nil, label: "全部")
                            ForEach(categories, id: \.self) { cat in
                                categoryChip(cat, label: cat)
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                }
            }

            // 单词列表
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
                            word.isMastered.toggle()
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
            description: Text("从扫描页拍照并保存词汇后，在这里查看和管理")
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
