//
//  CollectionReviewView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

struct CollectionReviewView: View {
    let title: String
    let collectionID: UUID?
    let entries: [WordCollectionEntry]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @State private var viewModel = CollectionReviewViewModel()
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
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadQueue()
        }
        .sheet(isPresented: $showResult) {
            ReviewResultView(results: viewModel.sessionResults) {
                showResult = false
                dismiss()
            }
        }
    }

    private var reviewContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                ProgressView(value: viewModel.progress)
                    .tint(.accentColor)
                    .padding(.horizontal)
                Text("\(viewModel.doneCount) / \(viewModel.totalCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            if let card = viewModel.currentCard {
                cardView(card)
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

    private func cardView(_ card: CollectionReviewCard) -> some View {
        ZStack {
            cardFace {
                VStack(spacing: 12) {
                    Label(card.entry.categoryName, systemImage: card.entry.sceneTag.icon)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tint)

                    Text(card.entry.word)
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
                    Text(card.entry.word)
                        .font(.title2.bold())

                    Divider()

                    Text(card.entry.chineseExplanation)
                        .font(.title3.weight(.medium))

                    if !card.entry.exampleSentence.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.entry.exampleSentence)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(card.entry.exampleSentenceChinese)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }

                    if !card.entry.sceneNote.isEmpty {
                        Text(card.entry.sceneNote)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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

    private var revealButton: some View {
        Button {
            viewModel.revealAnswer()
        } label: {
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

    private var ratingButtons: some View {
        VStack(spacing: 12) {
            Text("你记得多少？")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ratingButton(quality: 0, label: "忘了", color: .red)
                ratingButton(quality: 3, label: "有点难", color: .orange)
                ratingButton(quality: 4, label: "认识", color: .blue)
                ratingButton(quality: 5, label: "很简单", color: .green)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
    }

    private func ratingButton(quality: Int, label: String, color: Color) -> some View {
        Button {
            viewModel.rate(
                quality: quality,
                collectionID: collectionID,
                userID: authManager.currentUserID,
                context: modelContext
            )
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

    private var emptyState: some View {
        ContentUnavailableView(
            "今日已完成",
            systemImage: "checkmark.circle.fill",
            description: Text("这个词书暂无待复习的词")
        )
    }

    private func loadQueue() async {
        guard let userID = authManager.currentUserID else {
            viewModel.load(cards: [])
            return
        }

        var cards: [CollectionReviewCard] = []
        for entry in entries {
            if let state = try? CollectionStore.ensureUserWordState(for: entry, userID: userID, context: modelContext) {
                cards.append(CollectionReviewCard(entry: entry, state: state))
            }
        }
        viewModel.load(cards: cards)
    }
}

struct CollectionReviewCard: Identifiable {
    let entry: WordCollectionEntry
    let state: UserWordState

    var id: UUID { entry.id }
}

@MainActor
@Observable
final class CollectionReviewViewModel {
    var queue: [CollectionReviewCard] = []
    var currentIndex = 0
    var isShowingAnswer = false
    var sessionResults: [ReviewResult] = []
    var sessionComplete = false

    private let srService = SpacedRepetitionService()

    var currentCard: CollectionReviewCard? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    var progress: Double {
        guard !queue.isEmpty else { return 0 }
        return Double(currentIndex) / Double(queue.count)
    }

    var totalCount: Int { queue.count }
    var doneCount: Int { currentIndex }

    func load(cards: [CollectionReviewCard]) {
        queue = cards.filter { $0.state.isDueForReview }.shuffled()
        currentIndex = 0
        isShowingAnswer = false
        sessionResults = []
        sessionComplete = false
    }

    func revealAnswer() {
        isShowingAnswer = true
    }

    func rate(
        quality: Int,
        collectionID: UUID?,
        userID: String?,
        context: ModelContext
    ) {
        guard let card = currentCard else { return }

        let result = srService.calculateNextReview(
            quality: quality,
            easeFactor: card.state.easeFactor,
            interval: card.state.interval,
            repetitions: card.state.repetitions
        )

        card.state.easeFactor = result.newEaseFactor
        card.state.interval = result.newInterval
        card.state.repetitions = result.newRepetitions
        card.state.nextReviewDate = result.nextReviewDate
        card.state.lastReviewedAt = Date()
        card.state.updatedAt = Date()

        if let signal = LearningProfileStore.reviewSignal(for: quality) {
            let total = (card.state.confidence * Double(card.state.evidenceCount)) + signal
            card.state.evidenceCount += 1
            card.state.confidence = total / Double(card.state.evidenceCount)
            try? LearningProfileStore.updateFamiliarity(
                normalizedForm: card.entry.normalizedForm,
                ownerUserID: userID,
                signal: signal,
                source: .review,
                context: context
            )
        }

        let session = ReviewSession(
            wordID: card.entry.id,
            wordText: card.entry.word,
            quality: quality,
            intervalAfter: result.newInterval,
            ownerUserID: userID,
            collectionID: collectionID
        )
        context.insert(session)
        if let userID, let collectionID {
            try? CollectionStore.refreshCollectionProgress(collectionID: collectionID, userID: userID, context: context)
        }

        sessionResults.append(ReviewResult(word: card.entry.word, quality: quality))
        currentIndex += 1
        isShowingAnswer = false
        if currentIndex >= queue.count {
            sessionComplete = true
        }
    }
}
