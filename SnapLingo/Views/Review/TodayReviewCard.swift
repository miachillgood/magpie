//
//  TodayReviewCard.swift
//  SnapLingo
//
//  复习页最上面：今天要学几个词（数字用荧光笔划出来）、由什么组成、来自哪些场景，和「开始复习」。
//  复习完了换成「今天复习完了」+ 下一次复习的日子。所有内容左对齐。
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
    var onStart: () -> Void
    var onMore: () -> Void

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
            Text("今天要学")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.homeMuted)

            markedLine(String(localized: "**\(plan.remaining)** 个词", comment: "Big number with a highlighter mark, then the unit (Review tab: 'To study today: 12 words')"))
                .padding(.top, 2)

            Text(breakdown)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.homeInk.opacity(0.75))
                .padding(.top, 6)

            if !sources.isEmpty {
                sourcesLine
                    .padding(.top, 14)
            }

            Button(action: onStart) {
                HStack(spacing: 10) {
                    Text("开始复习")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 17, weight: .bold))
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

    /// “6 个到期复习 · 4 个新词”
    private var breakdown: String {
        let reviews = plan.reviewIDs.count
        let news = plan.newIDs.count
        switch (reviews > 0, news > 0) {
        case (true, true): return String(localized: "\(reviews) 个到期复习 · \(news) 个新词")
        case (true, false): return String(localized: "\(reviews) 个到期复习")
        default: return String(localized: "\(news) 个新词，第一次学")
        }
    }

    private var sourcesLine: some View {
        let minutes = max(1, Int((Double(plan.remaining) * 0.7).rounded(.up)))
        let first = sources[0].displayTitle
        let text = sources.count == 1
            ? String(localized: "来自 \(first) · 约 \(minutes) 分钟", comment: "First argument is a scene title")
            : String(localized: "来自 \(first) 等 \(sources.count) 个场景 · 约 \(minutes) 分钟", comment: "First argument is a scene title; second is the total number of scenes")
        return HStack(spacing: 10) {
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
                .font(.system(size: 13))
                .foregroundStyle(Theme.homeMuted)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
    }

    // MARK: - 复习完了 / 今天没有

    private var done: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(plan.doneToday > 0 ? "今天复习完了" : "今天没有要复习的词")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.homeMuted)

            if plan.doneToday > 0 {
                markedLine(String(localized: "**\(plan.doneToday)** 个词", comment: "Big number with a highlighter mark, then the unit (Review tab: 'To study today: 12 words')"))
                    .padding(.top, 2)
            }

            Text(upcomingText.map { String(localized: "下一次：\($0)", comment: "Next reviews, e.g. 'Next: Tomorrow 5 · Thursday 3'") } ?? String(localized: "拍一个新场景，积累更多单词"))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.homeInk.opacity(0.75))
                .padding(.top, 6)

            if backlog > 0 {
                Button(action: onMore) {
                    Label("再学 5 个新词", systemImage: "plus")
                        .font(.system(size: 17, weight: .bold))
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
