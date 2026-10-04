//
//  TodayReviewCard.swift
//  SnapLingo
//
//  复习页最上面的今日目标：今天还剩几个词（数字用荧光笔划出来），新词和复习各一条进度，
//  来自哪些场景，和「开始复习」。新词目标后面有 ✎，点了就地调每天几个新词（DailyGoalSheet）。
//  做完了换成「今日目标完成」+ 下一次复习的日子。所有内容左对齐。
//

import SwiftUI

struct TodayReviewCard: View {
    var plan: DailyPlan
    /// 今天要学的词来自哪些场景（词多的在前）
    var sources: [Scan]
    /// 之后几天的复习量（只用前两个有复习的日子）
    var upcoming: [ForecastDay]
    /// 还没排进计划的新词
    var backlog: Int
    var scale: CGFloat
    /// 每天新词上限（设置里的值）
    var dailyNewGoal: Int
    var onStart: () -> Void
    var onMore: () -> Void
    var onEditGoal: () -> Void
    /// 点「来自…」那张卡片：打开词最多的那张照片
    var onOpenSource: (Scan) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if plan.hasWork {
                todo
            } else {
                done
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            guard !appeared else { return }
            if reduceMotion { appeared = true } else {
                withAnimation(.easeOut(duration: 0.5).delay(0.15)) { appeared = true }
            }
        }
    }

    // MARK: - 有任务

    private var todo: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("今日目标")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.homeMuted)

            markedLine(String(localized: "**\(plan.remaining)** 个词", comment: "Big number with a highlighter mark, then the unit (Review tab: 'To study today: 12 words')"))
                .padding(.top, 2)

            progressRows
                .padding(.top, 10)

            if !sources.isEmpty {
                sourcesLine
                    .padding(.top, 14)
            }

            Button(action: onStart) {
                HStack(spacing: 10) {
                    Text("开始复习")
                    Image(systemName: "arrow.right")
                }
                .font(.body.weight(.bold))
                .foregroundStyle(Theme.cream)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Theme.homeInk, in: .capsule)
                .shadow(color: .black.opacity(0.18), radius: 12, y: 8)
            }
            .buttonStyle(.pressable)
            .padding(.top, 22)
        }
    }

    // MARK: - 两条进度

    /// 新词 3/10 ✎（可以点）和复习 2/6（今天没有复习就不显示）
    private var progressRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onEditGoal) {
                ProgressRow(
                    title: String(localized: "新词", comment: "Today goal row: new words"),
                    done: plan.newDone,
                    target: plan.newTarget,
                    progress: plan.newProgress,
                    tint: Theme.newWords,
                    note: plan.newTarget == 0
                        ? String(localized: "没有待学的新词", comment: "Today goal: no saved new words left to learn")
                        : plan.newTarget < dailyNewGoal
                        ? String(localized: "目标 \(dailyNewGoal)，只剩这些待学", comment: "Today goal: fewer saved words than the daily new-word goal")
                        : nil,
                    editable: true,
                    appeared: appeared
                )
            }
            .buttonStyle(.pressable)
            .accessibilityHint(Text("调整每天学几个新词"))

            if plan.reviewTarget > 0 {
                ProgressRow(
                    title: String(localized: "复习", comment: "Today goal row: reviews"),
                    done: plan.reviewsDone,
                    target: plan.reviewTarget,
                    progress: plan.reviewProgress,
                    tint: Theme.reviews,
                    note: nil,
                    editable: false,
                    appeared: appeared
                )
            }
        }
    }

    private var sourcesLine: some View {
        let minutes = max(1, Int((Double(plan.remaining) * 0.7).rounded(.up)))
        let first = sources[0].displayTitle
        let text = sources.count == 1
            ? String(localized: "来自 \(first) · 约 \(minutes) 分钟", comment: "First argument is a scene title")
            : String(localized: "来自 \(first) 等 \(sources.count) 个场景 · 约 \(minutes) 分钟", comment: "First argument is a scene title; second is the total number of scenes")
        return Button { onOpenSource(sources[0]) } label: {
            HStack(spacing: 10) {
            HStack(spacing: -9) {
                ForEach(sources.prefix(4)) { scan in
                    ScanThumbnail(scan: scan)
                        .frame(width: 28, height: 28)
                        .clipShape(.circle)
                        .overlay(Circle().stroke(Theme.sheet, lineWidth: 2))
                }
            }
            .accessibilityHidden(true)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Theme.homeMuted)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.homeMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.sheet.opacity(0.85), in: .rect(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.pressable)
    }

    // MARK: - 复习完了 / 今天没有

    private var done: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(plan.doneToday > 0 ? "今日目标完成 ✓" : "今天没有要复习的词")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.homeMuted)

            if plan.doneToday > 0 {
                markedLine(String(localized: "**\(plan.doneToday)** 个词", comment: "Big number with a highlighter mark, then the unit (Review tab: 'To study today: 12 words')"))
                    .padding(.top, 2)
            }

            Text(upcomingText.map { String(localized: "下一次：\($0)", comment: "Next reviews, e.g. 'Next: Tomorrow 5 · Thursday 3'") } ?? String(localized: "拍一个新场景，积累更多单词"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.homeInk.opacity(0.75))
                .padding(.top, 6)

            Button(action: onEditGoal) {
                HStack(spacing: 5) {
                    Text("每天 \(dailyNewGoal) 个新词", comment: "Today card when done: the daily new-word goal, tappable to change")
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.homeMuted)
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.pressable)
            .accessibilityHint(Text("调整每天学几个新词"))

            if backlog > 0 {
                Button(action: onMore) {
                    Label("再学 5 个新词", systemImage: "plus")
                        .font(.body.weight(.bold))
                        .foregroundStyle(Theme.homeInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Theme.sheet, in: .capsule)
                        .overlay(Capsule().strokeBorder(Theme.homeInk.opacity(0.06)))
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                }
                .buttonStyle(.pressable)
                .padding(.top, 22)
            }
        }
    }

    /// “明天 5 个 · 周四 3 个”
    private var upcomingText: String? {
        let parts = upcoming.prefix(2).map { day in
            let name = HomeDates.upcomingName(for: day.date)
            return String(localized: "\(name) \(day.count) 个", comment: "Upcoming reviews on a day, e.g. 'Tomorrow: 5'")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - 数字

    /// “**12** 个词”：数字用荧光笔划出来，其余是单位；各语言可以把单位放在数字前后
    private func markedLine(_ phrase: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            ForEach(Array(HeadlinePiece.phrase(phrase).enumerated()), id: \.offset) { _, piece in
                if case .marker(let number) = piece {
                    markedNumber(number)
                } else {
                    Text(piece.plainText)
                        .font(.system(size: 24 * min(scale, 1.05), weight: .heavy))
                        .foregroundStyle(Theme.homeInk)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// 大数字 + 黄色荧光笔（和首页「捡到 4 个新词」同一种写法）
    private func markedNumber(_ value: String) -> some View {
        Text(value)
            .font(.brand(76 * scale))
            .kerning(-1.5)
            .foregroundStyle(Theme.homeInk)
            .contentTransition(.numericText())
            .padding(.horizontal, 10)
            // 荧光笔只划过数字的下半截
            .background(alignment: .bottom) {
                MarkerHighlight(drawn: appeared, cornerScale: 0.8)
                    .frame(height: 30 * scale)
                    .offset(y: -12 * scale)
            }
            .padding(.leading, -10)
    }
}

/// 一条目标进度：名字、完成数 / 目标数、细进度条；可改的那条带 ✎
private struct ProgressRow: View {
    var title: String
    var done: Int
    var target: Int
    var progress: Double
    var tint: Color
    var note: String?
    var editable: Bool
    var appeared: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: title)
                    .font(.subheadline.weight(.bold))
                Text(verbatim: "\(done) / \(target)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .contentTransition(.numericText())
                if editable {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.homeMuted)
                }
                if let note {
                    Text(verbatim: note)
                        .font(.caption)
                        .foregroundStyle(Theme.homeMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.homeInk)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.homeInk.opacity(0.08))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(proxy.size.width * (appeared ? progress : 0), progress > 0 ? 8 : 0))
                        .animation(.smooth(duration: 0.6), value: appeared)
                }
            }
            .frame(height: 8)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
