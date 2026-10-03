//
//  ReviewSections.swift
//  SnapLingo
//
//  复习页下面三块：最近一周的复习圆环、按场景复习、词库入口。
//

import SwiftUI

/// 复习页里的二级页面
enum ReviewRoute: Hashable {
    case library(WordsFilter, searching: Bool = false)
    case month(Date)
    /// 错词重练列表
    case mistakes
    /// 一个文件夹或一个分类里的词
    case collection(CollectionWordsView.Source)
}

// MARK: - 最近一周

/// 一行日期，借用「健身」App 的活动圆环：
/// 外圈 = 那天复习了多少（满环 = 完成每日目标），中间的点 = 那天拍过（词越多颜色越深）。
/// 今天像「日历」App 一样，日期数字放进实心圆里。
struct RecentDaysStrip: View {
    var days: [ReviewDay]
    /// 满环需要的复习次数
    var dailyGoal: Int
    var onPick: (Date) -> Void
    var onMonth: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 放得下就一行（中文）；外语的说明比较长，挪到标题下面
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    title
                    hint.fixedSize()
                    Spacer(minLength: 6)
                    monthButton
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        title
                        Spacer(minLength: 6)
                        monthButton
                    }
                    hint
                }
            }
            .foregroundStyle(Theme.homeInk)

            HStack(spacing: 0) {
                ForEach(days) { day in
                    DayRing(day: day, goal: dailyGoal) { onPick(day.date) }
                        .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 16) {
                HStack(spacing: 5) {
                    Circle().fill(Theme.dayDot).frame(width: 7, height: 7)
                    Text("新词")
                }
                HStack(spacing: 5) {
                    Circle()
                        .trim(from: 0, to: 0.72)
                        .stroke(DayRing.ringColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 10, height: 10)
                    Text("复习")
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.homeMuted)
            .accessibilityHidden(true)
        }
    }

    private var title: some View {
        Text("最近一周")
            .font(.system(size: 18, weight: .heavy))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityAddTraits(.isHeader)
    }

    private var hint: some View {
        Text("点一天，复习那天的词")
            .font(.system(size: 12))
            .foregroundStyle(Theme.homeMuted)
            .lineLimit(1)
    }

    private var monthButton: some View {
        Button(action: onMonth) {
            HStack(spacing: 2) {
                Text(monthLabel)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Theme.homeInk)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("查看整月")
    }

    private var monthLabel: String {
        HomeDates.monthName(for: days.last?.date ?? Date())
    }

    static func color(forShade shade: Int) -> Color {
        Theme.dayDot.opacity([0, 0.35, 0.65, 1][min(max(shade, 0), 3)])
    }
}

private struct DayRing: View {
    var day: ReviewDay
    var goal: Int
    var action: () -> Void

    static let ringColor = Theme.sparkle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private var isToday: Bool { Calendar.current.isDateInToday(day.date) }
    private var progress: Double { day.reviewProgress(goal: goal) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(HomeDates.narrowWeekday(for: day.date))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.homeMuted)

                ZStack {
                    Circle()
                        .stroke(Theme.homeInk.opacity(0.08), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: shown ? progress : 0)
                        .stroke(Self.ringColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    if day.hasCaptures {
                        Circle()
                            .fill(RecentDaysStrip.color(forShade: day.shade))
                            .padding(8)
                    }
                }
                .frame(width: 34, height: 34)

                Text("\(Calendar.current.component(.day, from: day.date))")
                    .font(.system(size: 13, weight: isToday || day.hasCaptures ? .bold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(isToday ? Theme.cream : (day.hasCaptures ? Theme.homeInk : Theme.homeMuted))
                    .frame(width: 26, height: 26)
                    .background {
                        if isToday { Circle().fill(Theme.homeInk) }
                    }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // 没拍东西的日子点了也没有内容，但不能用 disabled（会被系统调暗，圆环就看不清了）
        .allowsHitTesting(day.hasCaptures)
        .onAppear {
            guard !shown else { return }
            if reduceMotion { shown = true } else {
                withAnimation(.easeOut(duration: 0.7).delay(0.15)) { shown = true }
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [isToday ? String(localized: "今天") : HomeDates.dateText(for: day.date)]
        if day.hasCaptures { parts.append(String(localized: "拍了 \(day.scanCount) 个场景，\(day.wordCount) 个词")) }
        if day.reviewed {
            parts.append(String(localized: "复习了 \(day.reviewCount) 次"))
            if progress >= 1 { parts.append(String(localized: "完成目标", comment: "Accessibility: reached the daily review goal")) }
        } else {
            parts.append(String(localized: "没有复习"))
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - 词库

/// 词库入口：总数 + 待学 / 学习中 / 已掌握，点哪个就打开筛选好的词库
/// 复习页底部「我的进度」：一条四段的横条（已掌握 / 学习中 / 待学 / 太简单）、这周新掌握几个。
/// 点标题进词库，点图例里的一段进对应的筛选
struct LibraryEntryCard: View {
    var progress: LearningProgress

    private struct Segment: Identifiable {
        var id: String { title }
        var title: String
        var count: Int
        var color: Color
        var filter: WordsFilter
    }

    /// 横条只用柔和的颜色：灰绿 = 已掌握，荧光黄 = 学习中，浅米色 = 还没学，和页面的米色底是一家
    private static let sage = Color(light: UIColor(hex: 0x7FA38D), dark: UIColor(hex: 0x6E9A82))
    private static let track = Color(light: UIColor(hex: 0xE9E1D3), dark: UIColor(hex: 0x3A352E))

    private var segments: [Segment] {
        [
            Segment(title: String(localized: "已掌握", comment: "Progress card segment: mastered"), count: progress.mastered, color: Self.sage, filter: .mastered),
            Segment(title: String(localized: "学习中", comment: "Progress card segment: learning"), count: progress.learning, color: Theme.marker, filter: .learning),
            Segment(title: String(localized: "待学", comment: "Progress card segment: new"), count: progress.new, color: Self.track, filter: .new),
            Segment(title: String(localized: "太简单", comment: "Progress card segment: removed as too easy"), count: progress.tooEasy, color: Self.track.opacity(0.6), filter: .mastered)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NavigationLink(value: ReviewRoute.library(.all)) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("我的进度")
                        .font(.system(size: 18, weight: .heavy))
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("\(progress.total) 个词")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.homeMuted)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.homeMuted)
                }
                .foregroundStyle(Theme.homeInk)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: "\(progress.mastered)")
                    .font(.brand(30))
                Text("个已掌握", comment: "After the big mastered-words number on the progress card")
                    .font(.system(size: 15, weight: .semibold))
                    .fixedSize()
                // 横条和数字放在同一行
                bar
                    .padding(.leading, 8)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                if progress.masteredThisWeek > 0 {
                    Text("这周 +\(progress.masteredThisWeek)", comment: "Progress card: words newly mastered in the last 7 days")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.success)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.success.opacity(0.12), in: .capsule)
                }
            }
            .foregroundStyle(Theme.homeInk)

            FlowLayout(spacing: 8) {
                ForEach(segments.filter { $0.count > 0 }) { segment in
                    NavigationLink(value: ReviewRoute.library(segment.filter)) {
                        HStack(spacing: 6) {
                            Circle().fill(segment.color).frame(width: 8, height: 8)
                                .overlay(Circle().strokeBorder(Theme.homeInk.opacity(segment.color == Self.track ? 0.25 : 0), lineWidth: 1))
                            Text(verbatim: segment.title)
                            Text(verbatim: "\(segment.count)")
                                .fontWeight(.bold)
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.homeInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.cream, in: .capsule)
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
        .padding(16)
        .background(Theme.sheet, in: .rect(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    /// 四段横条，按词数分宽度
    private var bar: some View {
        GeometryReader { proxy in
            let total = max(progress.total, 1)
            let shown = segments.filter { $0.count > 0 }
            let gaps = CGFloat(max(shown.count - 1, 0)) * 3
            HStack(spacing: 3) {
                ForEach(shown) { segment in
                    segment.color
                        .frame(width: max((proxy.size.width - gaps) * CGFloat(segment.count) / CGFloat(total), 6))
                }
            }
            .clipShape(.capsule)
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }
}
