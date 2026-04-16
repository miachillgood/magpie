//
//  WordSelectionView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

struct WordSelectionView: View {
    let ocrResult: OCRResult
    let sourceImage: UIImage

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WordSelectionViewModel()
    @State private var scanSessionID = UUID()   // 本次扫描的唯一 ID
    @State private var showCategorySheet = false
    @State private var newCategoryInput = ""

    // 读取用户水平
    @Query private var settingsArray: [AppSettings]
    private var settings: AppSettings? { settingsArray.first }

    // 历史分类（用于分类编辑 sheet）
    @Query private var allWords: [VocabWord]
    private var historicalCategories: [String] {
        let cats = Set(allWords.map(\.categoryName)).subtracting(["通用"])
        return cats.sorted()
    }

    var body: some View {
        @Bindable var coordinator = coordinator

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // 原图（自然比例，下拉弹性，不裁剪）
                GeometryReader { geo in
                    let minY = geo.frame(in: .named("wordSelectionScroll")).minY
                    let stretch = max(0, minY)
                    Image(uiImage: sourceImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height + stretch)
                        .clipped()
                        .cornerRadius(12)
                        .offset(y: -stretch)
                }
                .aspectRatio(sourceImage.size, contentMode: .fit)
                .padding(.horizontal)

                // 分类标签（可编辑）
                HStack {
                    Button {
                        newCategoryInput = viewModel.editableCategory
                        showCategorySheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.detectedScene.icon)
                            Text(viewModel.editableCategory)
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text("共 \(viewModel.presentedWords.count) 个词")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Divider().padding(.horizontal)

                // 词汇芯片区
                if viewModel.isLoadingKeywords {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("AI 正在分析词汇…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("重试") {
                            Task { await loadKeywords() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .padding(.horizontal)
                } else {
                    // 流式布局词汇芯片
                    FlowLayout(spacing: 10) {
                        ForEach(viewModel.presentedWords) { word in
                            WordChipView(
                                word: word.word,
                                isSelected: viewModel.isSelected(word.word),
                                likelyKnown: word.likelyKnown
                            ) {
                                viewModel.toggle(word.word)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // 提示说明
                    if !viewModel.presentedWords.isEmpty {
                        Text("蓝色边框 = AI 推荐学习 · 勾选你不认识的词")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal)
                    }
                }

                Spacer(minLength: 100) // 底部按钮留空
            }
            .padding(.vertical)
        }
        .coordinateSpace(name: "wordSelectionScroll")
        .navigationTitle("选择词汇")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            confirmButton
        }
        .task { await loadKeywords() }
        .sheet(isPresented: $showCategorySheet) {
            categoryPickerSheet
        }
        .navigationDestination(for: WordDetailRoute.self) { route in
            WordDetailView(
                words: route.words,
                sourceImage: route.sourceImage,
                sceneTag: route.sceneTag,
                ocrText: route.ocrText,
                scanSessionID: route.scanSessionID,
                categoryName: route.categoryName
            )
        }
    }

    // MARK: - 确认按钮

    private var confirmButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                confirmAndNavigate()
            } label: {
                Text("学习这 \(viewModel.selectedWordTexts.count) 个词 →")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.canConfirm ? Color.accentColor : Color.secondary.opacity(0.3))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                    .padding(.vertical, 12)
            }
            .disabled(!viewModel.canConfirm)
        }
        .background(.regularMaterial)
    }

    // MARK: - 分类选择 Sheet

    private var categoryPickerSheet: some View {
        NavigationStack {
            List {
                Section("输入新分类") {
                    HStack {
                        TextField("例如：咖啡店、健身房…", text: $newCategoryInput)
                            .autocorrectionDisabled()
                        if !newCategoryInput.isEmpty {
                            Button {
                                newCategoryInput = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !historicalCategories.isEmpty {
                    Section("历史分类") {
                        ForEach(historicalCategories, id: \.self) { cat in
                            Button {
                                viewModel.editableCategory = cat
                                showCategorySheet = false
                            } label: {
                                HStack {
                                    Text(cat)
                                    Spacer()
                                    if cat == viewModel.editableCategory {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .navigationTitle("选择分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showCategorySheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认") {
                        let trimmed = newCategoryInput.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            viewModel.editableCategory = trimmed
                        }
                        showCategorySheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - 动作

    private func loadKeywords() async {
        let level = settings?.estimatedUserLevel ?? .unknown
        await viewModel.loadKeywords(from: ocrResult.fullText, userLevel: level)
    }

    private func confirmAndNavigate() {
        // 水平评估写回（仅首次，即 unknown 状态时）
        if settings?.estimatedUserLevel == .unknown || settings == nil {
            let level = viewModel.estimatedLevel()
            if let s = settings {
                s.estimatedUserLevel = level
            } else {
                let newSettings = AppSettings()
                newSettings.estimatedUserLevel = level
                modelContext.insert(newSettings)
            }
        }

        coordinator.scanPath.append(WordDetailRoute(
            words: Array(viewModel.selectedWordTexts),
            sourceImage: sourceImage,
            sceneTag: viewModel.detectedScene,
            ocrText: ocrResult.fullText,
            scanSessionID: scanSessionID,
            categoryName: viewModel.editableCategory
        ))
    }
}

// MARK: - 词汇详情路由（第四阶段替换占位）

struct WordDetailRoute: Hashable {
    let words: [String]
    let sourceImage: UIImage
    let sceneTag: SceneTag
    let ocrText: String
    let scanSessionID: UUID
    let categoryName: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(words)
        hasher.combine(ObjectIdentifier(sourceImage))
    }
    static func == (lhs: WordDetailRoute, rhs: WordDetailRoute) -> Bool {
        lhs.words == rhs.words && lhs.sourceImage === rhs.sourceImage
    }
}

// MARK: - 流式布局（Chips 换行）

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var rowX: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowX + size.width > width, rowX > 0 {
                height += rowHeight + spacing
                rowX = 0
                rowHeight = 0
            }
            rowX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var rowX = bounds.minX
        var rowY = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowX + size.width > bounds.maxX, rowX > bounds.minX {
                rowY += rowHeight + spacing
                rowX = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: rowX, y: rowY), proposal: ProposedViewSize(size))
            rowX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
