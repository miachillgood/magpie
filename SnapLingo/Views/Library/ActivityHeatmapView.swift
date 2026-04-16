//
//  ActivityHeatmapView.swift
//  SnapLingo
//

import SwiftUI

struct ActivityHeatmapView: View {
    let activityByDate: [Date: Int]
    @Binding var selectedDate: Date?

    private let weeks = 12
    private let cellSize: CGFloat = 22
    private let cellSpacing: CGFloat = 3
    private let labelWidth: CGFloat = 18

    // 生成过去 12 周的日期网格（7行 × 12列）
    // 列 = 周（旧 → 新），行 = 周一到周日
    private var grid: [[Date?]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // 找到今天是本周的第几天（周一=1）
        let weekday = cal.component(.weekday, from: today)  // 1=周日, 2=周一 ... 7=周六
        let daysFromMonday = (weekday + 5) % 7  // 周一=0, 周日=6

        // 本周周一
        let thisMonday = cal.date(byAdding: .day, value: -daysFromMonday, to: today)!
        // 12 周前的周一（最左列）
        let startMonday = cal.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisMonday)!

        // 生成 12 列（每列 7 天）
        return (0..<weeks).map { weekOffset in
            (0..<7).map { dayOffset in
                let date = cal.date(byAdding: .day, value: weekOffset * 7 + dayOffset, to: startMonday)!
                return date > today ? nil : date  // 未来的格子置 nil
            }
        }
    }

    // 每列对应的月份标签（若该列第一天是新月份则显示）
    private func monthLabel(for col: Int) -> String? {
        let cal = Calendar.current
        guard let firstDate = grid[col].compactMap({ $0 }).first else { return nil }
        let month = cal.component(.month, from: firstDate)
        // 第一列始终显示，其他列只在月份变化时显示
        if col == 0 { return monthAbbr(month) }
        guard let prevFirst = grid[col - 1].compactMap({ $0 }).first else { return nil }
        let prevMonth = cal.component(.month, from: prevFirst)
        return month != prevMonth ? monthAbbr(month) : nil
    }

    private func monthAbbr(_ month: Int) -> String {
        let names = ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"]
        return names[safe: month - 1] ?? ""
    }

    private func cellColor(for date: Date?) -> Color {
        guard let date else { return Color.clear }
        let count = activityByDate[date] ?? 0
        switch count {
        case 0:    return Color.secondary.opacity(0.15)
        case 1...3: return Color.accentColor.opacity(0.3)
        case 4...7: return Color.accentColor.opacity(0.65)
        default:   return Color.accentColor
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 月份标签行
            HStack(spacing: cellSpacing) {
                Spacer().frame(width: labelWidth)
                ForEach(0..<weeks, id: \.self) { col in
                    Text(monthLabel(for: col) ?? "")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: cellSize, alignment: .leading)
                }
            }

            // 主网格：行 = 周几，列 = 周
            HStack(alignment: .top, spacing: cellSpacing) {
                // 左侧行标签（只显示 Mon / Wed / Fri）
                VStack(spacing: cellSpacing) {
                    ForEach(0..<7, id: \.self) { row in
                        Text(rowLabel(row))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .frame(width: labelWidth, height: cellSize, alignment: .trailing)
                    }
                }

                // 格子
                ForEach(0..<weeks, id: \.self) { col in
                    VStack(spacing: cellSpacing) {
                        ForEach(0..<7, id: \.self) { row in
                            let date = grid[col][row]
                            let isSelected = date.map { Calendar.current.isDate($0, inSameDayAs: selectedDate ?? .distantPast) } ?? false
                            let isToday = date.map { Calendar.current.isDateInToday($0) } ?? false

                            RoundedRectangle(cornerRadius: 4)
                                .fill(cellColor(for: date))
                                .frame(width: cellSize, height: cellSize)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(
                                            isSelected ? Color.accentColor :
                                            isToday ? Color.primary.opacity(0.4) : Color.clear,
                                            lineWidth: isSelected ? 2 : 1
                                        )
                                )
                                .onTapGesture {
                                    if let d = date {
                                        selectedDate = (selectedDate.map { Calendar.current.isDate($0, inSameDayAs: d) } ?? false) ? nil : d
                                    }
                                }
                        }
                    }
                }
            }

            // 图例
            HStack(spacing: 4) {
                Spacer()
                Text("少")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                ForEach([0.15, 0.3, 0.65, 1.0], id: \.self) { opacity in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(opacity < 0.2 ? Color.secondary.opacity(0.15) : Color.accentColor.opacity(opacity))
                        .frame(width: 12, height: 12)
                }
                Text("多")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }

    private func rowLabel(_ row: Int) -> String {
        switch row {
        case 0: return "M"
        case 2: return "W"
        case 4: return "F"
        default: return ""
        }
    }
}

// MARK: - 安全下标

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
