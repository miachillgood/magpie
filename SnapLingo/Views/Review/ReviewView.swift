//
//  ReviewView.swift
//  SnapLingo
//
//  “复习”标签页：今日计划、待学的词、未来一周的复习量。
//

import SwiftUI
import SwiftData
import Charts

struct ReviewView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Query private var words: [VocabWord]
    @Query(sort: \ReviewLog.reviewedAt) private var logs: [ReviewLog]
    @Query(sort: \UserSettings.createdAt) private var settingsRows: [UserSettings]

    private var settings: UserSettings? { settingsRows.first }

    private var plan: DailyPlan {
        guard let settings else { return .empty }
        return StudyStore.plan(settings: settings, words: words, logs: logs)
    }

    private var backlogCount: Int { words.filter { $0.state == .new && !$0.excludedFromReview }.count }

    var body: some View {
        NavigationStack {
            Group {
                if words.isEmpty {
                    IllustratedEmptyState(
                        emoji: "🗂️",
                        color: Pastel.sky,
                        title: "还没有要复习的词",
                        message: "拍一个英文场景，挑几个词，之后每天在这里按计划复习。",
                        buttonTitle: "扫描一个场景"
                    ) { coordinator.startScan() }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Spacing.xl) {
                            PlanCard(plan: plan, backlog: backlogCount)
                            if backlogCount > plan.newIDs.count {
                                backlogRow
                            }
                            if words.contains(where: { $0.state != .new }) {
                                ForecastCard(days: DailyPlanner.forecast(words: words))
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.sm)
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(PaperBackground())
            .navigationTitle("复习")
            .appTabBar()
        }
    }

    private var backlogRow: some View {
        Button {
            coordinator.showWords(.new)
        } label: {
            HStack(spacing: Spacing.sm) {
                EmojiTile(emoji: "📥", color: Pastel.peach, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(backlogCount) 个词待学")
                        .font(.headline.weight(.heavy))
                        .contentTransition(.numericText())
                    Text("每天按计划学一部分，不会一下子太多")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink.opacity(0.4))
            }
            .card(padding: Spacing.sm + 2)
        }
        .buttonStyle(.pressable)
        .foregroundStyle(Theme.ink)
    }
}

// MARK: - 今日计划卡片

private struct PlanCard: View {
    @Environment(AppCoordinator.self) private var coordinator
    var plan: DailyPlan
    var backlog: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(spacing: Spacing.lg) {
                ZStack {
                    PlanRingView(newProgress: plan.newProgress, reviewProgress: plan.reviewProgress, lineWidth: 13)
                        .frame(width: 108, height: 108)
                    if plan.isComplete {
                        Text("🎉").font(.system(size: 34))
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        VStack(spacing: -2) {
                            Text("\(plan.remaining)")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .contentTransition(.numericText())
                            Text("待完成")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(headline)
                        .font(.title3.weight(.heavy))
                    ProgressLine(color: Theme.newWords, title: "新词", done: plan.newDone, target: plan.newTarget)
                    ProgressLine(color: Theme.reviews, title: "复习", done: plan.reviewsDone, target: plan.reviewTarget)
                }
            }

            if plan.hasWork {
                PrimaryButton(title: plan.doneToday > 0 ? "继续学习" : "开始今日学习", trailingSymbol: "arrow.right") {
                    coordinator.startStudy()
                }
            } else if backlog > 0 {
                SecondaryButton(title: "再学 5 个新词", symbol: "plus") {
                    coordinator.startStudy(.today(extraNew: 5))
                }
            } else {
                SecondaryButton(title: "扫描一个新场景", symbol: "camera.viewfinder") {
                    coordinator.startScan()
                }
            }
        }
        .card(padding: Spacing.lg, radius: Radius.hero)
        .animation(.spring, value: plan)
    }

    private var headline: String {
        if plan.isComplete { return "今日计划完成" }
        if !plan.hasWork { return "今天没有要学的词" }
        return "今日计划"
    }
}

private struct ProgressLine: View {
    var color: Color
    var title: String
    var done: Int
    var target: Int

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Capsule().fill(color).frame(width: 14, height: 6)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("\(done)/\(target)")
                .font(.subheadline.weight(.heavy).monospacedDigit())
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 未来一周

private struct ForecastCard: View {
    var days: [ForecastDay]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title: "未来一周", emoji: "📊", subtitle: "每天要复习的词")
            Chart(days) { day in
                BarMark(
                    x: .value("日期", day.date, unit: .day),
                    y: .value("复习", max(day.count, 0))
                )
                .foregroundStyle(Calendar.current.isDateInToday(day.date) ? Theme.brand : Theme.reviews.opacity(0.55))
                .clipShape(.rect(cornerRadius: 8, style: .continuous))
                .annotation(position: .top, spacing: 3) {
                    if day.count > 0 {
                        Text("\(day.count)")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(Calendar.current.isDateInToday(date) ? "今天" : date.formatted(.dateTime.weekday(.narrow)))
                                .font(.caption2.weight(.bold))
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 130)
        }
        .card(padding: Spacing.lg, radius: Radius.hero)
    }
}
