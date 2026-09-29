//
//  ActivityHeatmapView.swift
//  SnapLingo
//

import SwiftUI

/// 最近几周每天的学习量（品牌色深浅表示）
struct ActivityHeatmapView: View {
    /// 当天 0 点 → 学习次数
    let activity: [Date: Int]
    var weeks = 16

    private let spacing: CGFloat = 3
    private let calendar = Calendar.current

    /// 列是周，行是一周的七天（从当地的周首日开始）
    private var grid: [[Date?]] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        guard let thisWeekStart = calendar.date(byAdding: .day, value: -offset, to: today),
              let start = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisWeekStart) else { return [] }
        return (0..<weeks).map { week in
            (0..<7).map { day in
                guard let date = calendar.date(byAdding: .day, value: week * 7 + day, to: start) else { return nil }
                return date > today ? nil : date
            }
        }
    }

    private var activeDays: Int { activity.values.filter { $0 > 0 }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            GeometryReader { proxy in
                let cell = (proxy.size.width - spacing * CGFloat(weeks - 1)) / CGFloat(weeks)
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(Array(grid.enumerated()), id: \.offset) { _, column in
                        VStack(spacing: spacing) {
                            ForEach(0..<7, id: \.self) { row in
                                cellView(date: column[row])
                                    .frame(width: cell, height: cell)
                            }
                        }
                    }
                }
            }
            .aspectRatio(CGFloat(weeks) / 7, contentMode: .fit)

            HStack(spacing: 4) {
                Text("最近 \(weeks) 周学习了 \(activeDays) 天")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("少").font(.caption2).foregroundStyle(.secondary)
                ForEach([0, 1, 8, 20], id: \.self) { count in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(color(for: count))
                        .frame(width: 10, height: 10)
                }
                Text("多").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("最近 \(weeks) 周学习了 \(activeDays) 天")
    }

    @ViewBuilder
    private func cellView(date: Date?) -> some View {
        if let date {
            let count = activity[date] ?? 0
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color(for: count))
                .overlay {
                    if calendar.isDateInToday(date) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.5), lineWidth: 1)
                    }
                }
        } else {
            Color.clear
        }
    }

    private func color(for count: Int) -> Color {
        switch count {
        case 0:       Theme.insetFill
        case 1...5:   Theme.brand.opacity(0.3)
        case 6...15:  Theme.brand.opacity(0.6)
        default:      Theme.brand
        }
    }
}
