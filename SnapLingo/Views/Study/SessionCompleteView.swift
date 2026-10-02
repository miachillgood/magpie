//
//  SessionCompleteView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

struct SessionCompleteView: View {
    let session: StudySession
    var onMore: () -> Void
    var onDone: () -> Void

    @Query private var words: [VocabWord]
    @Query(sort: \ReviewLog.reviewedAt) private var logs: [ReviewLog]
    @Query(sort: \UserSettings.createdAt) private var settingsRows: [UserSettings]
    @Environment(\.modelContext) private var context
    @State private var celebrate = 0
    @State private var appeared = false
    /// 这一屏里刚回答过「节奏合适吗？」，显示调整后的结果
    @State private var paceAnswered = false

    private var plan: DailyPlan {
        guard let settings = settingsRows.first else { return .empty }
        return StudyStore.plan(settings: settings, words: words, logs: logs)
    }

    private var backlog: Int { words.filter { $0.state == .new && !$0.excludedFromReview }.count }
    private var nextDay: ForecastDay? { DailyPlanner.nextReviewDay(words: words) }
    private var streak: Int { DailyPlanner.streak(events: logs) }
    private var accuracy: Int {
        session.completedCount == 0 ? 0 : session.rememberedCount * 100 / session.completedCount
    }

    /// 结算页要不要放「节奏合适吗？」卡片
    private var showsPaceCheck: Bool {
        guard let settings = settingsRows.first, case .today = session.scope else { return false }
        return paceAnswered || StudyPace.shouldAsk(plan: plan, backlog: backlog, asked: settings.paceCheckDone)
    }

    var body: some View {
        // 多一张卡片时圆环缩小、间距收紧，小屏也放得下「完成」按钮
        let tight = showsPaceCheck
        ZStack {
            VStack(spacing: tight ? Spacing.sm : Spacing.xl) {
                Spacer()

                ZStack {
                    PlanRingView(newProgress: plan.newProgress, reviewProgress: plan.reviewProgress, lineWidth: 18)
                        .frame(width: tight ? 120 : 190, height: tight ? 120 : 190)
                    Text(session.completedCount > 0 ? "🎉" : "☕️")
                        .font(.system(size: tight ? 44 : 64))
                        .scaleEffect(appeared ? 1 : 0.3)
                        .rotationEffect(.degrees(appeared ? 0 : -30))
                }

                VStack(spacing: Spacing.xs) {
                    Text(title)
                        .font(.system(size: 32, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if session.completedCount > 0 {
                    HStack(spacing: Spacing.sm) {
                        StatTile(value: session.newLearnedCount, label: "新词", emoji: "✨", color: Pastel.peach)
                        StatTile(value: session.reviewedCount, label: "复习", emoji: "🔁", color: Pastel.lavender)
                        StatTile(value: accuracy, label: "记住率", emoji: "🧠", color: Pastel.mint, suffix: "%")
                    }
                    if streak > 0 {
                        Text("🔥 已经连续学习 \(streak) 天")
                            .font(.subheadline.weight(.heavy))
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs)
                            .background(Pastel.butter, in: .capsule)
                    }
                }

                if showsPaceCheck, let settings = settingsRows.first {
                    PaceCheckCard(settings: settings, newDone: plan.newDone, backlog: backlog, answered: paceAnswered) { step in
                        answerPace(settings: settings, step: step)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }

                Spacer()

                VStack(spacing: Spacing.sm) {
                    PrimaryButton(title: "完成", symbol: "checkmark", action: onDone)
                    if !plan.hasWork && backlog > 0, case .today = session.scope {
                        SecondaryButton(title: "再学 5 个新词", symbol: "plus", action: onMore)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.md)

            ConfettiView(trigger: session.completedCount > 0 ? celebrate : 0)
                .ignoresSafeArea()
        }
        .sensoryFeedback(.success, trigger: celebrate)
        .onAppear {
            celebrate += 1
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.15)) { appeared = true }
        }
    }

    private func answerPace(settings: UserSettings, step: Int) {
        withAnimation(.snappy) {
            settings.newWordsPerDay = StudyPace.adjusted(settings.newWordsPerDay, by: step)
            settings.paceCheckDone = true
            paceAnswered = true
        }
        try? context.save()
        StudyReminder.refresh(context: context)
    }

    private var title: String {
        if session.completedCount == 0 { return String(localized: "今天没有要学的词") }
        return plan.hasWork ? String(localized: "这一轮完成！") : String(localized: "今日计划完成！")
    }

    private var subtitle: String {
        if let nextDay {
            if Calendar.current.isDateInTomorrow(nextDay.date) {
                return String(localized: "明天有 \(nextDay.count) 个词要复习，记得回来。")
            }
            let day = nextDay.date.formatted(.dateTime.month().day())
            return String(localized: "下次复习在 \(day)，共 \(nextDay.count) 个词。")
        }
        return String(localized: "去扫描一个新场景，积累更多单词吧。")
    }
}

/// 结算页的「节奏合适吗？」：第一次有新词因为每日上限在排队时问一次，往上或往下挪一档
private struct PaceCheckCard: View {
    let settings: UserSettings
    var newDone: Int
    var backlog: Int
    var answered: Bool
    var onAnswer: (Int) -> Void

    var body: some View {
        VStack(spacing: Spacing.sm) {
            if answered {
                Text("以后每天 \(settings.newWordsPerDay) 个新词，可以在“我的”里改")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 4) {
                    Text("节奏合适吗？")
                        .font(.headline.weight(.heavy))
                    Text("今天的 \(newDone) 个新词学完了，还有 \(backlog) 个在排队。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: Spacing.xs) {
                    choice("少一点", step: -1)
                    choice("刚好", step: 0)
                    choice("多一点", step: 1)
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity)
        .card(padding: Spacing.md)
    }

    private func choice(_ title: LocalizedStringKey, step: Int) -> some View {
        Button { onAnswer(step) } label: {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(step == 0 ? Theme.ink : Theme.insetFill, in: .capsule)
                .foregroundStyle(step == 0 ? Theme.onInk : Theme.ink)
        }
        .buttonStyle(.pressable)
    }
}
