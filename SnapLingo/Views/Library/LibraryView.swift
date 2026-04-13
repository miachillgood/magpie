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
    @State private var selectedWord: VocabWord?

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
                ocrText: word.exampleSentence
            )
        }
    }

    // MARK: - 列表

    private var scanSessions: [ScanSession] { viewModel.scanSessions(from: allWords) }

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

            // 扫描历史胶卷（有多次扫描时才显示）
            if scanSessions.count > 1 {
                Section("扫描历史") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(scanSessions) { session in
                                scanSessionCard(session)
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 6)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                }
            }

            // 场景过滤芯片
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        sceneChip(nil, label: "全部")
                        ForEach(SceneTag.allCases, id: \.self) { scene in
                            sceneChip(scene, label: scene.rawValue)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
            }

            // 单词列表
            Section("\(filtered.count) 个词汇") {
                ForEach(filtered) { word in
                    NavigationLink(value: word) {
                        VocabWordRowView(word: word)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        // 删除
                        Button(role: .destructive) {
                            modelContext.delete(word)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        // 标记已掌握
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

    // MARK: - 扫描历史卡片

    private func scanSessionCard(_ session: ScanSession) -> some View {
        let isSelected = viewModel.selectedSessionID == session.id
        return Button {
            viewModel.selectedSessionID = isSelected ? nil : session.id
        } label: {
            VStack(spacing: 4) {
                // 缩略图或占位
                Group {
                    if let data = session.thumbnail, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.secondary.opacity(0.15)
                            .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
                )

                Text("\(session.wordCount) 词")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                Text(session.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(width: 72)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 场景过滤芯片

    private func sceneChip(_ scene: SceneTag?, label: String) -> some View {
        let selected = viewModel.selectedScene == scene
        return Button {
            viewModel.selectedScene = scene
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
