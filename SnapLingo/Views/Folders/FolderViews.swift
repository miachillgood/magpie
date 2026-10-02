//
//  FolderViews.swift
//  SnapLingo
//
//  分类和文件夹的界面：复习页的「我的文件夹」「分类」两块、拍完照的选择行、新建 / 编辑文件夹、
//  以及点进去以后的单词列表（文件夹和分类共用）。
//

import SwiftUI
import SwiftData

// MARK: - 颜色

enum CollectionStyle {
    /// 分类格子外面那一大块粉色
    static let gridBackground = Color(light: UIColor(hex: 0xFBE3E6), dark: UIColor(hex: 0x3A2A2D))
    /// 格子交替用的暖橙和米色
    static let warmTile = Color(light: UIColor(hex: 0xFCE3C8), dark: UIColor(hex: 0x4A3624))
    static let creamTile = Color(light: UIColor(hex: 0xFDF3E7), dark: UIColor(hex: 0x2E2822))
    static let selected = Color(light: UIColor(hex: 0xF6E3A8), dark: UIColor(hex: 0x5A4A1E))
}

extension SceneType {
    /// 某个词算哪一类：用户手动改过的优先，否则看它最近一次出现的那张照片
    static func of(_ word: VocabWord) -> SceneType {
        if !word.categoryOverrideRaw.isEmpty { return SceneType(key: word.categoryOverrideRaw) }
        return word.latestScan?.scene ?? .general
    }
}

// MARK: - 复习页：我的词夹

/// 一个格子：先放自己建的文件夹，再放有词的自动分类，最后一格是「＋ 新建」
struct CollectionGrid: View {
    var folders: [WordFolder]
    var categories: [(scene: SceneType, count: Int)]
    var sidePadding: CGFloat
    var onOpen: (CollectionWordsView.Source) -> Void
    var onNew: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    private struct Entry: Identifiable {
        var id: String
        var source: CollectionWordsView.Source
        var icon: String
        var name: String
        var count: Int
        var due: Int
    }

    private var entries: [Entry] {
        folders.map { Entry(id: $0.id.uuidString, source: .folder($0), icon: $0.iconName, name: $0.name, count: $0.words.count, due: $0.words.filter { $0.isDue(today: today) }.count) }
            + categories.map { Entry(id: $0.scene.rawValue, source: .category($0.scene), icon: $0.scene.iconName, name: $0.scene.displayName, count: $0.count, due: 0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("我的词夹")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Theme.homeInk)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, sidePadding)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    Button { onOpen(entry.source) } label: {
                        CollectionTile(icon: entry.icon, name: entry.name, count: entry.count, due: entry.due, fill: index.isMultiple(of: 2) ? CollectionStyle.warmTile : CollectionStyle.creamTile)
                    }
                    .buttonStyle(.pressable)
                }
                Button(action: onNew) {
                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 26, weight: .semibold))
                            .frame(height: 40)
                        Text("新建")
                            .font(.system(size: 13, weight: .bold))
                        Text(verbatim: " ")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Theme.homeMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.homeInk.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("新建文件夹")
            }
            .padding(12)
            .background(CollectionStyle.gridBackground, in: .rect(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, sidePadding - 4)
        }
    }
}

private struct CollectionTile: View {
    var icon: String
    var name: String
    var count: Int
    var due: Int
    var fill: Color

    var body: some View {
        VStack(spacing: 6) {
            IconImage(name: icon, size: 40)
            Text(name)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text("\(count) 个词", comment: "Category tile: number of words in it")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.homeMuted)
        }
        .foregroundStyle(Theme.homeInk)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .background(fill, in: .rect(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if due > 0 {
                Text(due, format: .number)
                    .font(.system(size: 11, weight: .heavy).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(Theme.brand, in: .capsule)
                    .padding(6)
                    .accessibilityLabel("\(due) 个要复习")
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CategoryTile: View {
    var scene: SceneType
    var count: Int?
    var fill: Color
    var isSelected = false

    var body: some View {
        VStack(spacing: 6) {
            IconImage(name: scene.iconName, size: 40)
            Text(scene.displayName)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if let count {
                Text("\(count) 个词", comment: "Category tile: number of words in it")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.homeMuted)
            }
        }
        .foregroundStyle(Theme.homeInk)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .background(isSelected ? CollectionStyle.selected : fill, in: .rect(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(isSelected ? Theme.homeInk : .clear, lineWidth: 2))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - 拍完照：改分类

struct CategoryPickerSheet: View {
    @Binding var selection: SceneType
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(SceneType.allCases.enumerated()), id: \.element) { index, scene in
                        Button {
                            selection = scene
                            dismiss()
                        } label: {
                            CategoryTile(scene: scene, count: nil, fill: index.isMultiple(of: 2) ? CollectionStyle.warmTile : CollectionStyle.creamTile, isSelected: scene == selection)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(12)
                .background(CollectionStyle.gridBackground, in: .rect(cornerRadius: 28, style: .continuous))
                .padding(Spacing.md)
            }
            .navigationTitle("选个分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .background(Theme.mist.ignoresSafeArea())
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - 拍完照：放进文件夹

struct FolderPickerRow: View {
    var folders: [WordFolder]
    @Binding var selected: Set<UUID>
    var onNew: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("放进文件夹")
                    .font(.headline.weight(.heavy))
                Text("可选")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(folders) { folder in
                        let isOn = selected.contains(folder.id)
                        Button {
                            withAnimation(.snappy) {
                                if isOn { selected.remove(folder.id) } else { selected.insert(folder.id) }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                IconImage(name: folder.iconName, size: 22)
                                Text(folder.name)
                                    .font(.subheadline.weight(.bold))
                                    .lineLimit(1)
                                if isOn {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.heavy))
                                }
                            }
                            .foregroundStyle(Theme.homeInk)
                            .padding(.horizontal, 12)
                            .frame(height: 40)
                            .background(isOn ? CollectionStyle.selected : Theme.insetFill, in: .capsule)
                            .overlay(Capsule().strokeBorder(isOn ? Theme.homeInk : .clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.pressable)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                    Button(action: onNew) {
                        Label(folders.isEmpty ? "新建文件夹" : "新建", systemImage: "plus")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.homeInk)
                            .padding(.horizontal, 12)
                            .frame(height: 40)
                            .overlay(Capsule().strokeBorder(Theme.homeInk.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                    }
                    .buttonStyle(.pressable)
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
        .sensoryFeedback(.selection, trigger: selected)
    }
}

// MARK: - 新建 / 编辑文件夹

struct FolderEditorView: View {
    /// nil 是新建
    var folder: WordFolder?
    var onSaved: (WordFolder) -> Void = { _ in }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var icon = IconLibrary.defaultFolderIcon
    @FocusState private var nameFocused: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    VStack(spacing: Spacing.sm) {
                        IconImage(name: icon, size: 72)
                            .frame(width: 104, height: 104)
                            .background(Theme.card, in: .rect(cornerRadius: 28, style: .continuous))
                            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
                            .contentTransition(.opacity)
                        TextField("文件夹名字", text: $name)
                            .font(.title3.weight(.heavy))
                            .multilineTextAlignment(.center)
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .padding(.vertical, 12)
                            .background(Theme.card, in: .capsule)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("选个图标")
                            .font(.headline.weight(.heavy))
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(IconLibrary.all, id: \.self) { name in
                                Button {
                                    withAnimation(.snappy) { icon = name }
                                } label: {
                                    IconImage(name: name, size: 34)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(name == icon ? CollectionStyle.selected : Theme.card, in: .rect(cornerRadius: 14, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(name == icon ? Theme.homeInk : .clear, lineWidth: 2))
                                }
                                .buttonStyle(.pressable)
                                .accessibilityLabel(String(name.dropFirst(5)))
                                .accessibilityAddTraits(name == icon ? .isSelected : [])
                            }
                        }
                    }
                }
                .foregroundStyle(Theme.homeInk)
                .padding(Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.mist.ignoresSafeArea())
            .navigationTitle(folder == nil ? "新建文件夹" : "编辑文件夹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(folder == nil ? "创建" : "完成") { save() }
                        .fontWeight(.bold)
                        .disabled(trimmed.isEmpty)
                }
            }
            .sensoryFeedback(.selection, trigger: icon)
        }
        .onAppear {
            if let folder {
                name = folder.name
                icon = folder.iconName
            } else {
                nameFocused = true
            }
        }
    }

    private func save() {
        let saved: WordFolder
        if let folder {
            WordLibrary.update(folder, name: trimmed, iconName: icon, context: context)
            saved = folder
        } else {
            saved = WordLibrary.createFolder(name: trimmed, iconName: icon, context: context)
        }
        onSaved(saved)
        dismiss()
    }
}

// MARK: - 点进去：单词列表

struct CollectionWordsView: View {
    enum Source: Hashable {
        case folder(WordFolder)
        case category(SceneType)
    }

    let source: Source

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \VocabWord.addedAt, order: .reverse) private var allWords: [VocabWord]
    @State private var editing = false
    @State private var confirmingDelete = false

    // 多选整理
    @State private var selecting = false
    @State private var selection: Set<UUID> = []
    @State private var picking: MoveTargetSheet.Mode?
    @State private var confirmingBatchDelete = false
    @State private var toast: String?

    private var words: [VocabWord] {
        switch source {
        case .folder(let folder): folder.words.sorted { $0.addedAt > $1.addedAt }
        case .category(let scene): allWords.filter { SceneType.of($0) == scene }
        }
    }

    private var title: String {
        switch source {
        case .folder(let folder): folder.name
        case .category(let scene): scene.displayName
        }
    }

    private var iconName: String {
        switch source {
        case .folder(let folder): folder.iconName
        case .category(let scene): scene.iconName
        }
    }

    private var folder: WordFolder? {
        if case .folder(let folder) = source { return folder }
        return nil
    }

    private var selectedWords: [VocabWord] { words.filter { selection.contains($0.id) } }

    var body: some View {
        let words = words
        List {
            if !selecting {
                Section { header(words) }
            }

            if words.isEmpty {
                Text(folder == nil ? "这一类还没有词" : "还没有词。拍完照保存时选这个文件夹，或者在单词页里把词加进来。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.homeMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(words) { word in
                        if selecting {
                            selectableRow(word)
                        } else {
                            NavigationLink(value: word) {
                                WordRow(word: word, showsScene: folder != nil)
                            }
                            .listRowBackground(Theme.card)
                            .swipeActions(edge: .trailing) {
                                if let folder {
                                    Button("移出", role: .destructive) {
                                        withAnimation { WordLibrary.remove(word, from: folder, context: context) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.mist.ignoresSafeArea())
        .navigationTitle(selecting ? String(localized: "已选 \(selection.count) 个", comment: "Multi-select title: number of selected words") : "")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(selecting)
        .toolbar { toolbar(words) }
        .safeAreaBar(edge: .bottom) {
            if selecting { actionBar }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.onInk)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Theme.ink, in: .capsule)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { self.toast = nil }
                    }
            }
        }
        .animation(.smooth, value: selecting)
        .sensoryFeedback(.selection, trigger: selection)
        .sheet(isPresented: $editing) {
            FolderEditorView(folder: folder)
        }
        .sheet(item: $picking) { mode in
            MoveTargetSheet(mode: mode, current: source) { target in
                apply(mode, to: target)
            }
        }
        .confirmationDialog("删除文件夹“\(title)”？", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                guard let folder else { return }
                dismiss()
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    WordLibrary.delete(folder, context: context)
                }
            }
        } message: {
            Text("里面的词不会被删除，仍然在词库里。")
        }
        .confirmationDialog("删除 \(selection.count) 个词？", isPresented: $confirmingBatchDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                let targets = selectedWords
                finish(String(localized: "已删除 \(targets.count) 个词", comment: "Toast after deleting selected words"))
                WordLibrary.delete(targets, context: context)
            }
        } message: {
            Text("复习记录也会一起删掉。")
        }
    }

    private func header(_ words: [VocabWord]) -> some View {
        VStack(spacing: Spacing.sm) {
            IconImage(name: iconName, size: 64)
                .frame(width: 96, height: 96)
                .background(Theme.card, in: .rect(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
            Text(title)
                .font(.system(size: 26, weight: .heavy))
                .multilineTextAlignment(.center)
            Text("\(words.count) 个词", comment: "Folder or category page: number of words")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.homeMuted)
            if !words.isEmpty {
                PrimaryButton(title: "复习这些词", symbol: "play.fill") {
                    coordinator.startStudy(.words(words.map(\.id)))
                }
                .padding(.top, Spacing.xs)
            }
        }
        .foregroundStyle(Theme.homeInk)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func selectableRow(_ word: VocabWord) -> some View {
        let isOn = selection.contains(word.id)
        return Button {
            if isOn { selection.remove(word.id) } else { selection.insert(word.id) }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isOn ? Theme.brand : Theme.homeInk.opacity(0.25))
                    .contentTransition(.symbolEffect(.replace))
                WordRow(word: word, showsScene: folder != nil)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowBackground(isOn ? CollectionStyle.selected.opacity(0.5) : Theme.card)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    @ToolbarContentBuilder
    private func toolbar(_ words: [VocabWord]) -> some ToolbarContent {
        if selecting {
            ToolbarItem(placement: .topBarLeading) {
                Button(selection.count == words.count ? "全不选" : "全选") {
                    selection = selection.count == words.count ? [] : Set(words.map(\.id))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") { stopSelecting() }
                    .fontWeight(.bold)
            }
        } else {
            if !words.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("选择") { selecting = true }
                }
            }
            if folder != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("编辑名字和图标", systemImage: "pencil") { editing = true }
                        Button("删除文件夹", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("文件夹操作")
                }
            }
        }
    }

    /// 多选时底部的操作：移到 / 复制到 / 移出（文件夹才有）/ 删除
    private var actionBar: some View {
        let empty = selection.isEmpty
        return HStack(spacing: 0) {
            barButton("移到…", symbol: "arrow.right.doc.on.clipboard") { picking = .move }
            if folder != nil {
                barButton("复制到…", symbol: "plus.square.on.square") { picking = .copy }
                barButton("移出", symbol: "minus.circle") {
                    guard let folder else { return }
                    let targets = selectedWords
                    WordLibrary.remove(targets, from: folder, context: context)
                    finish(String(localized: "已移出 \(targets.count) 个词", comment: "Toast after removing selected words from a folder"))
                }
            }
            barButton("删除", symbol: "trash", role: .destructive) { confirmingBatchDelete = true }
        }
        .disabled(empty)
        .opacity(empty ? 0.45 : 1)
        .padding(.vertical, 10)
        .padding(.horizontal, Spacing.sm)
        .background(Theme.card, in: .rect(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, 4)
    }

    private func barButton(_ title: LocalizedStringKey, symbol: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(role == .destructive ? Color.red : Theme.homeInk)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
    }

    private func apply(_ mode: MoveTargetSheet.Mode, to target: CollectionWordsView.Source) {
        let targets = selectedWords
        switch (mode, target) {
        case (.move, .folder(let destination)):
            WordLibrary.move(targets, from: folder, to: destination, context: context)
            // 从分类页放进文件夹：分类是自动的，词还留在原来的分类里
            finish(folder == nil
                   ? String(localized: "已放进「\(destination.name)」", comment: "Toast after adding words from a category page into a folder; the words stay in the category")
                   : String(localized: "已移到「\(destination.name)」", comment: "Toast after moving selected words; the argument is a folder or category name"))
        case (.copy, .folder(let destination)):
            WordLibrary.add(targets, to: destination, context: context)
            finish(String(localized: "已复制到「\(destination.name)」", comment: "Toast after copying selected words into a folder"))
        case (_, .category(let scene)):
            WordLibrary.setCategory(targets, to: scene, context: context)
            if let folder { WordLibrary.remove(targets, from: folder, context: context) }
            finish(String(localized: "已移到「\(scene.displayName)」", comment: "Toast after moving selected words; the argument is a folder or category name"))
        }
    }

    private func finish(_ message: String) {
        stopSelecting()
        withAnimation(.smooth) { toast = message }
    }

    private func stopSelecting() {
        selecting = false
        selection = []
    }
}

// MARK: - 选目标：移到 / 复制到哪里

struct MoveTargetSheet: View {
    enum Mode: String, Identifiable {
        case move, copy
        var id: String { rawValue }
    }

    var mode: Mode
    /// 现在所在的词夹，显示成灰色
    var current: CollectionWordsView.Source
    var onPick: (CollectionWordsView.Source) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WordFolder.lastUsedAt, order: .reverse) private var folders: [WordFolder]
    @State private var creating = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    private struct Target: Identifiable {
        var id: String
        var source: CollectionWordsView.Source
        var icon: String
        var name: String
    }

    private var targets: [Target] {
        let folderTargets = folders.map { Target(id: $0.id.uuidString, source: .folder($0), icon: $0.iconName, name: $0.name) }
        guard mode == .move else { return folderTargets }
        return folderTargets + SceneType.allCases.map { Target(id: $0.rawValue, source: .category($0), icon: $0.iconName, name: $0.displayName) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(targets.enumerated()), id: \.element.id) { index, target in
                        let isCurrent = target.source == current
                        Button {
                            onPick(target.source)
                            dismiss()
                        } label: {
                            VStack(spacing: 6) {
                                IconImage(name: target.icon, size: 38)
                                Text(target.name)
                                    .font(.system(size: 13, weight: .bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                            .foregroundStyle(Theme.homeInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(index.isMultiple(of: 2) ? CollectionStyle.warmTile : CollectionStyle.creamTile, in: .rect(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.pressable)
                        .disabled(isCurrent)
                        .opacity(isCurrent ? 0.35 : 1)
                    }
                    Button { creating = true } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .frame(height: 38)
                            Text("新建文件夹")
                                .font(.system(size: 13, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .foregroundStyle(Theme.homeMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.homeInk.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
                    }
                    .buttonStyle(.pressable)
                }
                .padding(12)
                .background(CollectionStyle.gridBackground, in: .rect(cornerRadius: 28, style: .continuous))
                .padding(Spacing.md)
            }
            .background(Theme.mist.ignoresSafeArea())
            .navigationTitle(mode == .move ? "移到哪里？" : "复制到哪个文件夹？")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .sheet(isPresented: $creating) {
                FolderEditorView { folder in
                    onPick(.folder(folder))
                    dismiss()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - 单词页：在哪些文件夹里

struct WordFoldersRow: View {
    let word: VocabWord

    @Environment(\.modelContext) private var context
    @Query(sort: \WordFolder.lastUsedAt, order: .reverse) private var folders: [WordFolder]
    @State private var creating = false

    var body: some View {
        let mine = Set(word.folders.map(\.id))
        VStack(alignment: .leading, spacing: 10) {
            Text("文件夹")
                .font(.headline.weight(.heavy))
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(word.folders.sorted { $0.name < $1.name }) { folder in
                        HStack(spacing: 6) {
                            IconImage(name: folder.iconName, size: 20)
                            Text(folder.name)
                                .font(.subheadline.weight(.bold))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(CollectionStyle.selected, in: .capsule)
                    }
                    Menu {
                        ForEach(folders) { folder in
                            Button {
                                if mine.contains(folder.id) {
                                    WordLibrary.remove(word, from: folder, context: context)
                                } else {
                                    WordLibrary.add([word], to: folder, context: context)
                                }
                            } label: {
                                if mine.contains(folder.id) {
                                    Label(folder.name, systemImage: "checkmark")
                                } else {
                                    Text(folder.name)
                                }
                            }
                        }
                        Divider()
                        Button("新建文件夹…", systemImage: "plus") { creating = true }
                    } label: {
                        Label(word.folders.isEmpty ? "放进文件夹" : "管理", systemImage: word.folders.isEmpty ? "plus" : "folder")
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .overlay(Capsule().strokeBorder(Theme.homeInk.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(Theme.homeInk)
        .sheet(isPresented: $creating) {
            FolderEditorView { folder in
                WordLibrary.add([word], to: folder, context: context)
            }
        }
    }
}
