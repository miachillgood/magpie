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

    // 读取用户水平
    @Query private var settingsArray: [AppSettings]
    private var settings: AppSettings? { settingsArray.first }

    var body: some View {
        @Bindable var coordinator = coordinator

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // 场景标签
                HStack {
                    Image(systemName: viewModel.detectedScene.icon)
                    Text("场景：\(viewModel.detectedScene.rawValue)")
                    Spacer()
                    Text("共 \(viewModel.presentedWords.count) 个词")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline.weight(.medium))
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
        .navigationTitle("选择词汇")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            confirmButton
        }
        .task { await loadKeywords() }
        .navigationDestination(for: WordDetailRoute.self) { route in
            WordDetailView(
                words: route.words,
                sourceImage: route.sourceImage,
                sceneTag: route.sceneTag,
                ocrText: route.ocrText,
                scanSessionID: route.scanSessionID
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
            scanSessionID: scanSessionID
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
