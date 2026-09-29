//
//  SceneDetailView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

struct SceneDetailView: View {
    @Bindable var scan: Scan
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator

    @State private var showingPicker = false
    @State private var renaming = false
    @State private var titleDraft = ""
    @State private var confirmingDelete = false
    @State private var showingOCRText = false
    @State private var showsStickers = true

    private var sortedWords: [VocabWord] {
        scan.words.sorted { $0.addedAt > $1.addedAt }
    }

    private var studyableCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return scan.words.filter { word in
            !word.excludedFromReview && (word.state == .new || word.dueDate <= today)
        }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                photo
                header
                actions
                wordsSection
                if !scan.ocrText.isEmpty {
                    ocrSection
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, 40)
        }
        .background(alignment: .top) {
            scan.scene.pastel
                .frame(height: 380)
                .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea()
        }
        .background(PaperBackground())
        .navigationTitle(scan.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("重命名", systemImage: "pencil") {
                        titleDraft = scan.title
                        renaming = true
                    }
                    Picker(selection: $scan.sceneRaw) {
                        ForEach(SceneType.allCases) { scene in
                            Text("\(scene.emoji) \(scene.displayName)").tag(scene.rawValue)
                        }
                    } label: {
                        Label("场景类型", systemImage: "tag")
                    }
                    .pickerStyle(.menu)
                    Divider()
                    Button("删除场景", systemImage: "trash", role: .destructive) {
                        confirmingDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("更多操作")
            }
        }
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                WordPickerView(existingScan: scan)
            }
        }
        .alert("重命名场景", isPresented: $renaming) {
            TextField("场景名称", text: $titleDraft)
            Button("取消", role: .cancel) {}
            Button("保存") {
                scan.title = titleDraft
                try? context.save()
            }
        }
        .confirmationDialog("删除这个场景？", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("删除场景", role: .destructive) {
                // 先返回再删除，避免页面在退场动画中读到已删除的数据
                let target = scan
                dismiss()
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    WordLibrary.delete(target, context: context)
                }
            }
        } message: {
            Text("照片会被删除；只在这个场景里出现过的词也会一起删除，其他场景里也有的词会保留。")
        }
    }

    // MARK: - 照片 + 单词贴纸

    @ViewBuilder
    private var photo: some View {
        if let image = scan.fullImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .overlay {
                    if showsStickers {
                        StickerLayer(scan: scan)
                            .transition(.opacity)
                    }
                }
                .clipShape(.rect(cornerRadius: Radius.card, style: .continuous))
                .padding(8)
                .background(Theme.card, in: .rect(cornerRadius: Radius.hero, style: .continuous))
                .softShadow()
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        withAnimation(.snappy) { showsStickers.toggle() }
                    } label: {
                        Image(systemName: showsStickers ? "tag.fill" : "tag")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 38, height: 38)
                            .background(Theme.card, in: .circle)
                            .softShadow()
                    }
                    .padding(18)
                    .accessibilityLabel(showsStickers ? "隐藏单词贴纸" : "显示单词贴纸")
                }
                .padding(.top, Spacing.xs)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            EmojiTile(emoji: scan.scene.emoji, color: scan.scene.pastel, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(scan.displayTitle)
                    .font(.title2.weight(.heavy))
                Text("\(scan.scene.displayName) · \(scan.createdAt.formatted(.dateTime.month().day().hour().minute()))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: Spacing.sm) {
            if studyableCount > 0 {
                PrimaryButton(title: "学这个场景 · \(studyableCount)", symbol: "play.fill") {
                    coordinator.startStudy(.scan(scan.id))
                }
            }
            if !(scan.candidates.isEmpty && scan.tokens.isEmpty) {
                SecondaryButton(title: "再选几个词", symbol: "plus") {
                    showingPicker = true
                }
                .frame(maxWidth: studyableCount > 0 ? 150 : .infinity)
            }
        }
    }

    // MARK: - 单词

    @ViewBuilder
    private var wordsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "保存的词", emoji: "📝", subtitle: "\(scan.words.count) 个")
            if scan.words.isEmpty {
                Text("还没有从这个场景保存单词。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .card()
            } else {
                VStack(spacing: Spacing.xs) {
                    ForEach(sortedWords) { word in
                        NavigationLink(value: word) {
                            WordRow(word: word, showsScene: false)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.sm)
                                .background(Theme.card, in: .rect(cornerRadius: Radius.card - 4, style: .continuous))
                                .contentShape(.rect)
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }
        }
    }

    private var ocrSection: some View {
        DisclosureGroup(isExpanded: $showingOCRText) {
            Text(scan.ocrText)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Spacing.xs)
        } label: {
            Label("识别出的文字", systemImage: "text.alignleft")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.ink)
        }
        .tint(Theme.ink)
        .card()
    }
}

/// 在原图上把已保存的单词做成贴纸，点一下进入单词详情
private struct StickerLayer: View {
    var scan: Scan

    var body: some View {
        GeometryReader { proxy in
            let anchors = SceneAnchors.anchors(for: scan)
            let byID = Dictionary(uniqueKeysWithValues: scan.words.map { ($0.id, $0) })
            ForEach(Array(anchors.enumerated()), id: \.element.id) { index, anchor in
                if let word = byID[anchor.id] {
                    NavigationLink(value: word) {
                        WordSticker(word: anchor.word, gloss: anchor.gloss, compact: proxy.size.width < 300)
                    }
                    .buttonStyle(.pressable)
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -2 : 2))
                    .position(
                        x: min(max(anchor.point.x * proxy.size.width, 60), proxy.size.width - 60),
                        y: min(max(anchor.point.y * proxy.size.height - 16, 18), proxy.size.height - 18)
                    )
                }
            }
        }
    }
}
