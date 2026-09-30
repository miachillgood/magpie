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

    static let ringColor = Color(hex: 0xF2B928)

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

// MARK: - 按场景复习

/// 横向一排场景卡片，该复习的排在前面（和照片墙按时间排区分开）
struct SceneReviewRow: View {
    var scans: [Scan]
    var sidePadding: CGFloat
    var zoom: Namespace.ID

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("按场景复习")
                    .font(.system(size: 18, weight: .heavy))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("该复习的排在前面")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.homeMuted)
            }
            .foregroundStyle(Theme.homeInk)
            .padding(.horizontal, sidePadding)
            .overlay(alignment: .topTrailing) {
                JournalStickerView(kind: .sparkleStar).offset(x: -sidePadding - 4, y: -18)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(scans) { scan in
                        NavigationLink(value: scan) {
                            SceneReviewCard(scan: scan)
                                .matchedTransitionSource(id: scan.id, in: zoom)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.vertical, 6)
            }
            .contentMargins(.horizontal, sidePadding, for: .scrollContent)
            .scrollIndicators(.hidden)
        }
    }
}

private struct SceneReviewCard: View {
    var scan: Scan

    var body: some View {
        let counts = scan.studyCounts()
        VStack(alignment: .leading, spacing: 0) {
            ScanThumbnail(scan: scan)
                .frame(width: 142, height: 108)
                .clipped()
                .overlay(alignment: .topLeading) { badge(counts) }
            VStack(alignment: .leading, spacing: 2) {
                Text(scan.displayTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.homeInk)
                    .lineLimit(1)
                Text("\(scan.words.count) 个词")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.homeMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 142, alignment: .leading)
        .background(Theme.sheet, in: .rect(cornerRadius: 18, style: .continuous))
        .clipShape(.rect(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func badge(_ counts: (due: Int, new: Int)) -> some View {
        if counts.due > 0 {
            tag("\(counts.due) 个待复习", fill: Theme.marker)
        } else if counts.new > 0 {
            tag("\(counts.new) 个新词", fill: Theme.placeChip)
        }
    }

    private func tag(_ text: LocalizedStringKey, fill: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(Theme.homeInk)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(fill, in: .capsule)
            .padding(8)
    }
}

// MARK: - 词库

/// 词库入口：总数 + 待学 / 学习中 / 已掌握，点哪个就打开筛选好的词库
struct LibraryEntryCard: View {
    var total: Int
    var counts: [WordsFilter: Int]

    var body: some View {
        VStack(spacing: 12) {
            NavigationLink(value: ReviewRoute.library(.all)) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("词库")
                        .font(.system(size: 18, weight: .heavy))
                    Text("\(total) 个词")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.homeMuted)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.homeMuted)
                }
                .foregroundStyle(Theme.homeInk)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                ForEach([WordsFilter.new, .learning, .mastered], id: \.self) { filter in
                    NavigationLink(value: ReviewRoute.library(filter)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(counts[filter] ?? 0)")
                                .font(.brand(22))
                                .foregroundStyle(Theme.homeInk)
                            Text(filter.title)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.homeMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Theme.cream, in: .rect(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("\(filter.title) \(counts[filter] ?? 0) 个")
                }
            }
        }
        .padding(16)
        .background(Theme.sheet, in: .rect(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}
