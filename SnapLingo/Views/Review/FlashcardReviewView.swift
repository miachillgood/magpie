//
//  FlashcardReviewView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

struct FlashcardReviewView: View {
    let categoryName: String       // 显示用（"全部" 或具体分类名）
    let wordsToReview: [VocabWord] // 已过滤的待复习词

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ReviewViewModel()
    @State private var showResult = false

    var body: some View {
        Group {
            if viewModel.queue.isEmpty && !viewModel.sessionComplete {
                emptyState
            } else if viewModel.sessionComplete {
                emptyState.onAppear { showResult = true }
            } else {
                reviewContent
            }
        }
        .navigationTitle(categoryName)
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.loadExact(words: wordsToReview.filter(\.isDueForReview).shuffled()) }
        .sheet(isPresented: $showResult) {
            ReviewResultView(results: viewModel.sessionResults) {
                showResult = false
                dismiss()
            }
        }
    }

    // MARK: - 复习主界面

    private var reviewContent: some View {
        VStack(spacing: 0) {
            progressBar

            if let word = viewModel.currentWord {
                cardView(word: word)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                Spacer()

                if viewModel.isShowingAnswer {
                    ratingButtons
                } else {
                    revealButton
                }
            }
        }
    }

    // MARK: - 进度条

    private var progressBar: some View {
        VStack(spacing: 4) {
            ProgressView(value: viewModel.progress)
                .tint(.accentColor)
                .padding(.horizontal)
            Text("\(viewModel.doneCount) / \(viewModel.totalCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: - 翻转卡片

    private func cardView(word: VocabWord) -> some View {
        ZStack {
            cardFace {
                VStack(spacing: 12) {
                    Label(word.categoryName, systemImage: word.sceneTag.icon)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tint)

                    Text(word.word)
                        .font(.system(size: 42, weight: .bold))
                        .multilineTextAlignment(.center)

                    Text("点击「显示答案」查看解释")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                .padding(24)
            }
            .opacity(viewModel.isShowingAnswer ? 0 : 1)

            cardFace {
                VStack(alignment: .leading, spacing: 16) {
                    Text(word.word)
                        .font(.title2.bold())

                    Divider()

                    Text(word.chineseExplanation)
                        .font(.title3.weight(.medium))

                    if !word.exampleSentence.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(word.exampleSentence)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(word.exampleSentenceChinese)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .opacity(viewModel.isShowingAnswer ? 1 : 0)
            .rotation3DEffect(
                .degrees(viewModel.isShowingAnswer ? 0 : 180),
                axis: (x: 0, y: 1, z: 0)
            )
        }
        .animation(.spring(duration: 0.4), value: viewModel.isShowingAnswer)
    }

    private func cardFace<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.07), radius: 12, y: 4)
    }

    // MARK: - 显示答案按钮

    private var revealButton: some View {
        Button { viewModel.revealAnswer() } label: {
            Text("显示答案")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.tint)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
    }

    // MARK: - 评分按钮

    private var ratingButtons: some View {
        VStack(spacing: 12) {
            Text("你记得多少？")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ratingButton(quality: 0, label: "忘了",   color: .red)
                ratingButton(quality: 3, label: "有点难",  color: .orange)
                ratingButton(quality: 4, label: "认识",   color: .blue)
                ratingButton(quality: 5, label: "很简单", color: .green)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
    }

    private func ratingButton(quality: Int, label: String, color: Color) -> some View {
        Button {
            viewModel.rate(quality: quality, context: modelContext)
            if viewModel.sessionComplete { showResult = true }
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(color.opacity(0.15))
                .foregroundStyle(color)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(color.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 空状态

    private var emptyState: some View {
        ContentUnavailableView(
            "今日已完成",
            systemImage: "checkmark.circle.fill",
            description: Text("这个分类暂无待复习的词汇")
        )
    }
}
