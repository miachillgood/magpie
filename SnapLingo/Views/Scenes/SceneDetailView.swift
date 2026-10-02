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
    @State private var selectedWordID: UUID?

    private var sortedWords: [VocabWord] {
        scan.words.sorted { $0.addedAt > $1.addedAt }
    }

    private var studyableCount: Int {
        let counts = scan.studyCounts()
        return counts.due + counts.new
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
        .background(Theme.cream.ignoresSafeArea())
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
                            Label { Text(scene.displayName) } icon: { Image(scene.iconName) }.tag(scene.rawValue)
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

    // MARK: - 照片 + 荧光笔

    @ViewBuilder
    private var photo: some View {
        if let image = scan.fullImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .overlay {
                    if showsStickers {
                        WordMarkLayer(scan: scan, selected: $selectedWordID)
                            .transition(.opacity)
                    }
                }
                .clipShape(.rect(cornerRadius: Radius.card, style: .continuous))
                .padding(8)
                .background(Theme.card, in: .rect(cornerRadius: Radius.hero, style: .continuous))
                .softShadow()
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        withAnimation(.snappy) {
                            showsStickers.toggle()
                            selectedWordID = nil
                        }
                    } label: {
                        Image(systemName: showsStickers ? "highlighter" : "eye.slash")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 38, height: 38)
                            .background(Theme.card, in: .circle)
                            .softShadow()
                    }
                    .padding(18)
                    .accessibilityLabel(showsStickers ? "隐藏照片上的单词标记" : "显示照片上的单词标记")
                }
                .padding(.top, Spacing.xs)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            IconImage(name: scan.scene.iconName, size: 34)
                .frame(width: 52, height: 52)
                .background(Theme.placeChip, in: .rect(cornerRadius: 16, style: .continuous))
                .accessibilityHidden(true)
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
            SectionHeader(title: "保存的词", subtitle: "\(scan.words.count) 个")
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

/// 在原图上用荧光笔标出保存的词（不遮住原文）。点一下弹出释义，再点释义进入单词详情
private struct WordMarkLayer: View {
    var scan: Scan
    @Binding var selected: UUID?

    var body: some View {
        GeometryReader { proxy in
            let spots = WordCrops.spots(for: scan, limit: 60)
            ZStack(alignment: .topLeading) {
                // 点照片空白处收起释义
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture { withAnimation(.snappy) { selected = nil } }

                ForEach(spots) { spot in
                    let rect = frame(of: spot.rect, in: proxy.size)
                    RoundedRectangle(cornerRadius: max(3, rect.height * 0.25), style: .continuous)
                        .fill(Theme.marker.opacity(selected == spot.id ? 0.95 : 0.6))
                        .blendMode(.multiply)
                        .frame(width: rect.width, height: rect.height)
                        .padding(6)
                        .contentShape(.rect)
                        .onTapGesture {
                            withAnimation(.snappy) { selected = selected == spot.id ? nil : spot.id }
                        }
                        .position(x: rect.midX, y: rect.midY)
                        .accessibilityLabel(spot.word.word)
                        .accessibilityAddTraits(.isButton)
                }

                if let id = selected, let spot = spots.first(where: { $0.id == id }) {
                    let rect = frame(of: spot.rect, in: proxy.size)
                    NavigationLink(value: spot.word) {
                        WordSticker(word: spot.word.word, gloss: HomeView.shortGloss(spot.word.gloss) ?? "", highlighted: true)
                    }
                    .buttonStyle(.pressable)
                    .position(
                        x: min(max(rect.midX, 80), proxy.size.width - 80),
                        y: rect.minY - 24 < 20 ? rect.maxY + 24 : rect.minY - 24
                    )
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                    .accessibilityHint("查看这个词")
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
    }

    /// 归一化坐标 → 视图坐标，四周稍微放大一点
    private func frame(of rect: CGRect, in size: CGSize) -> CGRect {
        CGRect(x: rect.minX * size.width, y: rect.minY * size.height, width: rect.width * size.width, height: rect.height * size.height)
            .insetBy(dx: -3, dy: -2)
    }
}
