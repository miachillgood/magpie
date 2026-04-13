//
//  WordDetailView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData
import AVFoundation

struct WordDetailView: View {
    let words: [String]
    let sourceImage: UIImage?
    let sceneTag: SceneTag
    let ocrText: String
    var scanSessionID: UUID = UUID()

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WordDetailViewModel()
    @State private var currentPage = 0
    private let synthesizer = AVSpeechSynthesizer()

    var body: some View {
        VStack(spacing: 0) {
            // 进度指示
            if words.count > 1 {
                pageIndicator
            }

            // 分页卡片（TabView 横滑）
            TabView(selection: $currentPage) {
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    ExplanationCardView(
                        word: word,
                        scene: sceneTag,
                        explanation: viewModel.explanations[word],
                        isLoading: viewModel.isLoading(word),
                        isSaved: viewModel.isSaved(word)
                    ) {
                        viewModel.save(
                            word: word,
                            scene: sceneTag,
                            sourceImage: sourceImage,
                            scanSessionID: scanSessionID,
                            context: modelContext
                        )
                        // 保存后自动跳下一页
                        if index + 1 < words.count {
                            withAnimation { currentPage = index + 1 }
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)
        }
        .navigationTitle("\(currentPage + 1) / \(words.count)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                saveAllButton
            }
        }
        .task {
            await viewModel.loadAll(words: words, ocrText: ocrText, scene: sceneTag)
        }
        .onAppear {
            speakCurrentWord()
        }
        .onChange(of: currentPage) {
            speakCurrentWord()
        }
    }

    private func speakCurrentWord() {
        guard currentPage < words.count else { return }
        let word = words[currentPage]
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        synthesizer.speak(utterance)
    }

    // MARK: - 顶部分页点

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<words.count, id: \.self) { i in
                Circle()
                    .fill(i == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: i == currentPage ? 8 : 6, height: i == currentPage ? 8 : 6)
                    .animation(.spring(duration: 0.2), value: currentPage)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - 全部保存按钮

    private var saveAllButton: some View {
        let unsaved = words.filter { !viewModel.isSaved($0) }
        return Button("全部保存") {
            for word in unsaved {
                viewModel.save(word: word, scene: sceneTag, sourceImage: sourceImage, scanSessionID: scanSessionID, context: modelContext)
            }
        }
        .disabled(unsaved.isEmpty)
    }
}
