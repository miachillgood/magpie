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
    @State private var celebrate = 0
    @State private var appeared = false

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

    var body: some View {
        ZStack {
            VStack(spacing: Spacing.xl) {
                Spacer()

                ZStack {
                    PlanRingView(newProgress: plan.newProgress, reviewProgress: plan.reviewProgress, lineWidth: 18)
                        .frame(width: 190, height: 190)
                    Text(session.completedCount > 0 ? "🎉" : "☕️")
                        .font(.system(size: 64))
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

    private var title: String {
        if session.completedCount == 0 { return "今天没有要学的词" }
        return plan.hasWork ? "这一轮完成！" : "今日计划完成！"
    }

    private var subtitle: String {
        if let nextDay {
            if Calendar.current.isDateInTomorrow(nextDay.date) {
                return "明天有 \(nextDay.count) 个词要复习，记得回来。"
            }
            return "下次复习在 \(nextDay.date.formatted(.dateTime.month().day()))，共 \(nextDay.count) 个词。"
        }
        return "去扫描一个新场景，积累更多单词吧。"
    }
}
